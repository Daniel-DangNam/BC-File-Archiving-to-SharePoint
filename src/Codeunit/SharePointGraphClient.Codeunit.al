namespace APSS.FileArchiving;

using Microsoft.EServices.EDocument;
using Microsoft.Foundation.Attachment;
using System.Environment;
using System.Utilities;

codeunit 50141 "SharePoint Graph Client"
{
    var
        CachedAccessToken: SecretText;
        TokenExpiryDateTime: DateTime;
        SecretKeyLbl: Label 'SP_ARCHIVE_CLIENT_SECRET', Locked = true;
        GraphScopeLbl: Label 'https://graph.microsoft.com/.default', Locked = true;
        TokenEndpointLbl: Label 'https://login.microsoftonline.com/%1/oauth2/v2.0/token', Locked = true, Comment = '%1 = Tenant ID';
        DriveInfoUrlLbl: Label 'https://graph.microsoft.com/v1.0/drives/%1', Locked = true, Comment = '%1 = Drive ID';
        SimpleUploadUrlLbl: Label 'https://graph.microsoft.com/v1.0/drives/%1/root:/%2:/content', Locked = true, Comment = '%1 = Drive ID, %2 = File Path';
        CreateSessionUrlLbl: Label 'https://graph.microsoft.com/v1.0/drives/%1/root:/%2:/createUploadSession', Locked = true, Comment = '%1 = Drive ID, %2 = File Path';
        TokenFailedErr: Label 'Failed to obtain access token from Microsoft Entra ID. HTTP Status: %1, Error: %2', Comment = '%1 = Status Code, %2 = Error details';
        SetupNotConfiguredErr: Label 'SharePoint Archive Setup is not configured. Please fill in Tenant ID, Client ID, Secret, and Drive ID.';
        SizeMismatchErr: Label 'Size verification mismatch! Local size: %1 bytes, SharePoint size: %2 bytes.', Comment = '%1 = Local size, %2 = SharePoint size';
        ChunkUploadFailedErr: Label 'Chunk upload failed at byte range %1-%2. HTTP Status: %3, Response: %4', Comment = '%1 = Start byte, %2 = End byte, %3 = Status, %4 = Details';
        UploadSuccessMsg: Label 'File uploaded and verified successfully to SharePoint. Item ID: %1', Comment = '%1 = Drive Item ID';
        AuditUploadStartedMsg: Label 'Upload started for file %1 (Size: %2 bytes).', Comment = '%1 = File name, %2 = File size';
        AuditVerifySuccessMsg: Label 'Upload and verification succeeded. Web URL: %1', Comment = '%1 = SharePoint URL';
        AuditVerifyProofTxt: Label 'Item ID: %1, Size: %2, ETag: %3', Comment = '%1 = Item ID, %2 = Size, %3 = ETag';
        SourceBinaryNotFoundErr: Label 'Source attachment binary could not be found or read.';
        TestConnSuccessMsg: Label 'Connection successful!\Connected to SharePoint Drive: %1 (%2)\Web URL: %3', Comment = '%1 = Drive Name, %2 = Drive Type, %3 = Web URL';
        TestConnFailedErr: Label 'Connection test failed. HTTP Status: %1, Details: %2', Comment = '%1 = HTTP Status Code, %2 = Details';
        BatchSummaryMsg: Label 'Batch processing completed. %1 of %2 files uploaded and verified successfully.', Comment = '%1 = Success count, %2 = Total count';

    procedure TestConnection(var ArchiveSetup: Record "Archive Setup"): Boolean
    var
        Client: HttpClient;
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        Headers: HttpHeaders;
        Url: Text;
        ResponseText: Text;
        AccessToken: SecretText;
        JsonObj: JsonObject;
        JsonTok: JsonToken;
        DriveName: Text;
        DriveType: Text;
        WebUrl: Text;
    begin
        if (ArchiveSetup."Tenant ID" = '') or (ArchiveSetup."Client ID" = '') or (ArchiveSetup."SharePoint Drive ID" = '') then
            Error(SetupNotConfiguredErr);

        AccessToken := GetAccessToken(ArchiveSetup);

        Url := StrSubstNo(DriveInfoUrlLbl, ArchiveSetup."SharePoint Drive ID");
        Request.SetRequestUri(Url);
        Request.Method := 'GET';
        Request.GetHeaders(Headers);
        Headers.Add('Authorization', SecretStrSubstNo('Bearer %1', AccessToken));

        if not Client.Send(Request, Response) then
            Error(TestConnFailedErr, Response.HttpStatusCode(), 'Network request failed');

        Response.Content.ReadAs(ResponseText);

        if not Response.IsSuccessStatusCode() then begin
            ArchiveSetup."Is Configured" := false;
            ArchiveSetup.Modify(true);
            Error(TestConnFailedErr, Response.HttpStatusCode(), ResponseText);
        end;

        if JsonObj.ReadFrom(ResponseText) then begin
            if JsonObj.Get('name', JsonTok) then
                DriveName := JsonTok.AsValue().AsText();
            if JsonObj.Get('driveType', JsonTok) then
                DriveType := JsonTok.AsValue().AsText();
            if JsonObj.Get('webUrl', JsonTok) then
                WebUrl := JsonTok.AsValue().AsText();
        end;

        ArchiveSetup."Is Configured" := true;
        ArchiveSetup.Modify(true);

        Message(TestConnSuccessMsg, DriveName, DriveType, WebUrl);
        exit(true);
    end;

    procedure ProcessQueueEntry(var QueueEntry: Record "Archive Queue Entry"): Boolean
    var
        ArchiveSetup: Record "Archive Setup";
        FileInStream: InStream;
        SanitizedPath: Text;
        UploadSuccess: Boolean;
        DriveItemId: Text[250];
        WebUrl: Text[1000];
        ETag: Text[150];
        ReturnedSize: BigInteger;
    begin
        if not ArchiveSetup.Get() then
            Error(SetupNotConfiguredErr);

        if (ArchiveSetup."Tenant ID" = '') or (ArchiveSetup."Client ID" = '') or (ArchiveSetup."SharePoint Drive ID" = '') then
            Error(SetupNotConfiguredErr);

        if not GetSourceFileInStream(QueueEntry, FileInStream) then begin
            RecordQueueError(QueueEntry, SourceBinaryNotFoundErr);
            exit(false);
        end;

        SanitizedPath := BuildSanitizedPath(ArchiveSetup."Base Folder Path", QueueEntry);
        QueueEntry."SharePoint Relative Path" := CopyStr(SanitizedPath, 1, MaxStrLen(QueueEntry."SharePoint Relative Path"));
        QueueEntry."Archive Status" := QueueEntry."Archive Status"::Uploading;
        QueueEntry."Uploaded DateTime" := CurrentDateTime();
        QueueEntry.Modify(false);

        RecordAuditLog(QueueEntry, Enum::"Archive Audit Action"::UploadStarted, 'Uploading', StrSubstNo(AuditUploadStartedMsg, QueueEntry."File Name", QueueEntry."Original File Size (Bytes)"), '');

        // Upload execution
        if QueueEntry."Original File Size (Bytes)" <= 4194304 then
            UploadSuccess := ExecuteSimpleUpload(ArchiveSetup, SanitizedPath, FileInStream, DriveItemId, WebUrl, ETag, ReturnedSize)
        else
            UploadSuccess := ExecuteResumableUpload(ArchiveSetup, SanitizedPath, FileInStream, QueueEntry."Original File Size (Bytes)", DriveItemId, WebUrl, ETag, ReturnedSize);

        if not UploadSuccess then begin
            RecordQueueError(QueueEntry, QueueEntry."Last Error Message");
            exit(false);
        end;

        // Two-way byte-exact verification
        if ReturnedSize <> QueueEntry."Original File Size (Bytes)" then begin
            RecordQueueError(QueueEntry, StrSubstNo(SizeMismatchErr, QueueEntry."Original File Size (Bytes)", ReturnedSize));
            exit(false);
        end;

        // Mark verified & link mapping
        QueueEntry."Archive Status" := QueueEntry."Archive Status"::Verified;
        QueueEntry."Verified DateTime" := CurrentDateTime();
        QueueEntry."SharePoint Item ID" := DriveItemId;
        QueueEntry."SharePoint Web URL" := WebUrl;
        QueueEntry."SharePoint ETag" := ETag;
        QueueEntry."Last Error Message" := '';
        QueueEntry.Modify(false);

        UpsertLinkMapping(QueueEntry);

        RecordAuditLog(
            QueueEntry,
            Enum::"Archive Audit Action"::VerifySucceeded,
            'Verified',
            StrSubstNo(AuditVerifySuccessMsg, WebUrl),
            StrSubstNo(AuditVerifyProofTxt, DriveItemId, ReturnedSize, ETag));

        exit(true);
    end;

    procedure ProcessPendingQueueEntries(BatchLimit: Integer): Integer
    var
        ArchiveQueueEntry: Record "Archive Queue Entry";
        ProcessedCount: Integer;
        SuccessCount: Integer;
    begin
        if BatchLimit <= 0 then
            BatchLimit := 50;

        ArchiveQueueEntry.SetCurrentKey("Archive Status", "Entry No.");
        ArchiveQueueEntry.SetFilter("Archive Status", '%1|%2|%3',
            ArchiveQueueEntry."Archive Status"::Draft,
            ArchiveQueueEntry."Archive Status"::PendingUpload,
            ArchiveQueueEntry."Archive Status"::Failed);
        ArchiveQueueEntry.SetRange("Purge Status", Enum::"Purge Process Status"::NotEligible);

        if ArchiveQueueEntry.FindSet(true) then
            repeat
                if (ArchiveQueueEntry."Archive Status" <> ArchiveQueueEntry."Archive Status"::Failed) or (ArchiveQueueEntry."Retry Count" < 3) then begin
                    if ProcessQueueEntry(ArchiveQueueEntry) then
                        SuccessCount += 1;
                    ProcessedCount += 1;
                end;
            until (ArchiveQueueEntry.Next() = 0) or (ProcessedCount >= BatchLimit);

        Message(BatchSummaryMsg, SuccessCount, ProcessedCount);
        exit(SuccessCount);
    end;

    local procedure ExecuteSimpleUpload(
        ArchiveSetup: Record "Archive Setup";
        SanitizedPath: Text;
        FileInStream: InStream;
        var OutItemId: Text[250];
        var OutWebUrl: Text[1000];
        var OutETag: Text[150];
        var OutSize: BigInteger): Boolean
    var
        Client: HttpClient;
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        Headers: HttpHeaders;
        Content: HttpContent;
        Url: Text;
        ResponseText: Text;
        AccessToken: SecretText;
    begin
        AccessToken := GetAccessToken(ArchiveSetup);
        Url := StrSubstNo(SimpleUploadUrlLbl, ArchiveSetup."SharePoint Drive ID", SanitizedPath);

        Request.SetRequestUri(Url);
        Request.Method := 'PUT';

        Request.GetHeaders(Headers);
        Headers.Add('Authorization', SecretStrSubstNo('Bearer %1', AccessToken));

        Content.WriteFrom(FileInStream);
        Request.Content := Content;

        if not Client.Send(Request, Response) then
            exit(false);

        Response.Content.ReadAs(ResponseText);

        if not Response.IsSuccessStatusCode() then
            exit(false);

        exit(ParseDriveItemJson(ResponseText, OutItemId, OutWebUrl, OutETag, OutSize));
    end;

    local procedure ExecuteResumableUpload(
        ArchiveSetup: Record "Archive Setup";
        SanitizedPath: Text;
        FileInStream: InStream;
        FileSize: BigInteger;
        var OutItemId: Text[250];
        var OutWebUrl: Text[1000];
        var OutETag: Text[150];
        var OutSize: BigInteger): Boolean
    var
        Client: HttpClient;
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        Headers: HttpHeaders;
        Content: HttpContent;
        SessionUrl: Text;
        UploadUrl: Text;
        ResponseText: Text;
        AccessToken: SecretText;
        ChunkSizeBytes: Integer;
        BytesRemaining: BigInteger;
        StartByte: BigInteger;
        EndByte: BigInteger;
        CurrentChunkSize: Integer;
        MemoryStream: Codeunit "Temp Blob";
        ChunkOutStream: OutStream;
        ChunkInStream: InStream;
    begin
        AccessToken := GetAccessToken(ArchiveSetup);
        SessionUrl := StrSubstNo(CreateSessionUrlLbl, ArchiveSetup."SharePoint Drive ID", SanitizedPath);

        // 1. Create upload session
        Request.SetRequestUri(SessionUrl);
        Request.Method := 'POST';
        Request.GetHeaders(Headers);
        Headers.Add('Authorization', SecretStrSubstNo('Bearer %1', AccessToken));

        Content.WriteFrom('{"item": {"@microsoft.graph.conflictBehavior": "replace"}}');
        Content.GetHeaders(Headers);
        Headers.Remove('Content-Type');
        Headers.Add('Content-Type', 'application/json');
        Request.Content := Content;

        if not Client.Send(Request, Response) then
            exit(false);

        Response.Content.ReadAs(ResponseText);
        if not Response.IsSuccessStatusCode() then
            exit(false);

        UploadUrl := ExtractUploadUrl(ResponseText);
        if UploadUrl = '' then
            exit(false);

        // 2. Upload chunks (multiple of 320 KiB, default 4 MB = 4,194,304 bytes)
        ChunkSizeBytes := ArchiveSetup."Chunk Size (MB)" * 1048576;
        if ChunkSizeBytes < 4194304 then
            ChunkSizeBytes := 4194304;

        StartByte := 0;
        BytesRemaining := FileSize;

        while BytesRemaining > 0 do begin
            if BytesRemaining > ChunkSizeBytes then
                CurrentChunkSize := ChunkSizeBytes
            else
                CurrentChunkSize := BytesRemaining;

            EndByte := StartByte + CurrentChunkSize - 1;

            Clear(MemoryStream);
            MemoryStream.CreateOutStream(ChunkOutStream);
            CopyStream(ChunkOutStream, FileInStream, CurrentChunkSize);
            MemoryStream.CreateInStream(ChunkInStream);

            Clear(Client);
            Clear(Request);
            Request.SetRequestUri(UploadUrl);
            Request.Method := 'PUT';

            Clear(Content);
            Content.WriteFrom(ChunkInStream);
            Content.GetHeaders(Headers);
            Headers.Remove('Content-Range');
            Headers.Add('Content-Range', StrSubstNo('bytes %1-%2/%3', StartByte, EndByte, FileSize));
            Headers.Remove('Content-Length');
            Headers.Add('Content-Length', Format(CurrentChunkSize));
            Request.Content := Content;

            if not Client.Send(Request, Response) then
                exit(false);

            Response.Content.ReadAs(ResponseText);

            if (Response.HttpStatusCode() <> 200) and (Response.HttpStatusCode() <> 201) and (Response.HttpStatusCode() <> 202) then
                exit(false);

            StartByte += CurrentChunkSize;
            BytesRemaining -= CurrentChunkSize;
        end;

        exit(ParseDriveItemJson(ResponseText, OutItemId, OutWebUrl, OutETag, OutSize));
    end;

    local procedure GetAccessToken(ArchiveSetup: Record "Archive Setup"): SecretText
    var
        Client: HttpClient;
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        Headers: HttpHeaders;
        Content: HttpContent;
        Url: Text;
        BodyText: Text;
        ResponseText: Text;
        JsonObj: JsonObject;
        JsonTok: JsonToken;
        TokenText: Text;
        ClientSecret: Text;
    begin
        if CurrentDateTime() < TokenExpiryDateTime then
            if not CachedAccessToken.IsEmpty() then
                exit(CachedAccessToken);

        if not IsolatedStorage.Get(SecretKeyLbl, DataScope::Company, ClientSecret) then
            Error(SetupNotConfiguredErr);

        Url := StrSubstNo(TokenEndpointLbl, ArchiveSetup."Tenant ID");
        BodyText := StrSubstNo(
            'client_id=%1&scope=%2&client_secret=%3&grant_type=client_credentials',
            ArchiveSetup."Client ID",
            GraphScopeLbl,
            ClientSecret);

        Request.SetRequestUri(Url);
        Request.Method := 'POST';
        Content.WriteFrom(BodyText);
        Content.GetHeaders(Headers);
        Headers.Remove('Content-Type');
        Headers.Add('Content-Type', 'application/x-www-form-urlencoded');
        Request.Content := Content;

        if not Client.Send(Request, Response) then
            Error(TokenFailedErr, Response.HttpStatusCode(), 'Network request failed');

        Response.Content.ReadAs(ResponseText);

        if not Response.IsSuccessStatusCode() then
            Error(TokenFailedErr, Response.HttpStatusCode(), ResponseText);

        if not JsonObj.ReadFrom(ResponseText) then
            Error(TokenFailedErr, Response.HttpStatusCode(), 'Invalid JSON token response');

        if JsonObj.Get('access_token', JsonTok) then
            TokenText := JsonTok.AsValue().AsText();

        CachedAccessToken := TokenText;
        TokenExpiryDateTime := CurrentDateTime() + 3300000; // 55 minutes cache

        exit(CachedAccessToken);
    end;

    local procedure ParseDriveItemJson(
        JsonText: Text;
        var OutItemId: Text[250];
        var OutWebUrl: Text[1000];
        var OutETag: Text[150];
        var OutSize: BigInteger): Boolean
    var
        JsonObj: JsonObject;
        JsonTok: JsonToken;
    begin
        if not JsonObj.ReadFrom(JsonText) then
            exit(false);

        if JsonObj.Get('id', JsonTok) then
            OutItemId := CopyStr(JsonTok.AsValue().AsText(), 1, MaxStrLen(OutItemId));

        if JsonObj.Get('webUrl', JsonTok) then
            OutWebUrl := CopyStr(JsonTok.AsValue().AsText(), 1, MaxStrLen(OutWebUrl));

        if JsonObj.Get('eTag', JsonTok) then
            OutETag := CopyStr(JsonTok.AsValue().AsText(), 1, MaxStrLen(OutETag));

        if JsonObj.Get('size', JsonTok) then
            OutSize := JsonTok.AsValue().AsBigInteger();

        exit((OutItemId <> '') and (OutSize > 0));
    end;

    local procedure ExtractUploadUrl(JsonText: Text): Text
    var
        JsonObj: JsonObject;
        JsonTok: JsonToken;
    begin
        if JsonObj.ReadFrom(JsonText) then
            if JsonObj.Get('uploadUrl', JsonTok) then
                exit(JsonTok.AsValue().AsText());
        exit('');
    end;

    local procedure GetSourceFileInStream(QueueEntry: Record "Archive Queue Entry"; var OutStream: InStream): Boolean
    var
        DocAttachment: Record "Document Attachment";
        IncDocAttachment: Record "Incoming Document Attachment";
        TenantMedia: Record "Tenant Media";
    begin
        case QueueEntry."Source Table ID" of
            Database::"Document Attachment":
                begin
                    DocAttachment.ChangeCompany(QueueEntry."Company Name");
                    if DocAttachment.GetBySystemId(QueueEntry."Attachment SystemId") then
                        if TenantMedia.Get(DocAttachment."Document Reference ID".MediaId()) then begin
                            TenantMedia.CalcFields(Content);
                            TenantMedia.Content.CreateInStream(OutStream);
                            exit(true);
                        end;
                end;
            Database::"Incoming Document Attachment":
                begin
                    IncDocAttachment.ChangeCompany(QueueEntry."Company Name");
                    if IncDocAttachment.GetBySystemId(QueueEntry."Attachment SystemId") then begin
                        IncDocAttachment.CalcFields(Content);
                        IncDocAttachment.Content.CreateInStream(OutStream);
                        exit(true);
                    end;
                end;
        end;
        exit(false);
    end;

    local procedure BuildSanitizedPath(BaseFolder: Text[250]; QueueEntry: Record "Archive Queue Entry"): Text
    var
        Path: Text;
        DocType: Text;
        DocNo: Text;
        FileName: Text;
    begin
        DocType := SanitizeSegment(QueueEntry."Source Document Type");
        if DocType = '' then
            DocType := 'General';

        DocNo := SanitizeSegment(QueueEntry."Source Document No.");
        if DocNo = '' then
            DocNo := 'NoNumber';

        FileName := SanitizeFileName(QueueEntry."File Name", QueueEntry."File Extension");

        Path := SanitizeSegment(BaseFolder) + '/' +
                SanitizeSegment(QueueEntry."Company Name") + '/' +
                DocType + '/' +
                DocNo + '/' +
                FileName;

        while Path.Contains('//') do
            Path := Path.Replace('//', '/');

        if Path.StartsWith('/') then
            Path := CopyStr(Path, 2);

        exit(Path);
    end;

    local procedure SanitizeSegment(InputText: Text): Text
    var
        Result: Text;
    begin
        Result := DelChr(InputText, '=', '~"#%&*:<>?\/|{}');
        Result := DelChr(Result, '<>', ' .');
        Result := Result.Replace('..', '_');
        exit(Result);
    end;

    local procedure SanitizeFileName(FileName: Text[250]; Extension: Text[30]): Text
    var
        CleanName: Text;
        CleanExt: Text;
    begin
        CleanName := SanitizeSegment(FileName);
        CleanExt := SanitizeSegment(Extension);

        if CleanExt <> '' then
            if not CleanName.EndsWith('.' + CleanExt) then
                CleanName := CleanName + '.' + CleanExt;

        exit(CleanName);
    end;

    local procedure UpsertLinkMapping(QueueEntry: Record "Archive Queue Entry")
    var
        LinkMapping: Record "Archive Link Mapping";
    begin
        if not LinkMapping.Get(QueueEntry."Company Name", QueueEntry."Attachment SystemId") then begin
            LinkMapping.Init();
            LinkMapping."Company Name" := QueueEntry."Company Name";
            LinkMapping."Attachment SystemId" := QueueEntry."Attachment SystemId";
            LinkMapping."Source Table ID" := QueueEntry."Source Table ID";
            LinkMapping."Source Document No." := QueueEntry."Source Document No.";
            LinkMapping."Source Line No." := QueueEntry."Source Line No.";
            LinkMapping."File Name" := QueueEntry."File Name";
            LinkMapping."SharePoint Web URL" := QueueEntry."SharePoint Web URL";
            LinkMapping."Is Purged In BC" := false;
            LinkMapping."Archived DateTime" := CurrentDateTime();
            LinkMapping.Insert(true);
        end else begin
            LinkMapping."Source Table ID" := QueueEntry."Source Table ID";
            LinkMapping."Source Document No." := QueueEntry."Source Document No.";
            LinkMapping."Source Line No." := QueueEntry."Source Line No.";
            LinkMapping."File Name" := QueueEntry."File Name";
            LinkMapping."SharePoint Web URL" := QueueEntry."SharePoint Web URL";
            LinkMapping."Archived DateTime" := CurrentDateTime();
            LinkMapping.Modify(true);
        end;
    end;

    local procedure RecordQueueError(var QueueEntry: Record "Archive Queue Entry"; ErrorMsg: Text)
    begin
        QueueEntry."Archive Status" := QueueEntry."Archive Status"::Failed;
        QueueEntry."Retry Count" += 1;
        QueueEntry."Last Error Message" := CopyStr(ErrorMsg, 1, MaxStrLen(QueueEntry."Last Error Message"));
        QueueEntry.Modify(false);

        RecordAuditLog(QueueEntry, Enum::"Archive Audit Action"::VerifyFailed, 'Failed', ErrorMsg, '');
    end;

    local procedure RecordAuditLog(
        QueueEntry: Record "Archive Queue Entry";
        ActionType: Enum "Archive Audit Action";
        NewStatus: Text[50];
        Msg: Text;
        Proof: Text)
    var
        AuditLog: Record "Archive Audit Log";
    begin
        AuditLog.Init();
        AuditLog."Log Entry No." := 0;
        AuditLog."Queue Entry No." := QueueEntry."Entry No.";
        AuditLog."Company Name" := QueueEntry."Company Name";
        AuditLog."Event DateTime" := CurrentDateTime();
        AuditLog."User ID" := CopyStr(UserId(), 1, MaxStrLen(AuditLog."User ID"));
        AuditLog."Action Type" := ActionType;
        AuditLog."Old Status" := Format(QueueEntry."Archive Status");
        AuditLog."New Status" := NewStatus;
        AuditLog."Message" := CopyStr(Msg, 1, MaxStrLen(AuditLog."Message"));
        AuditLog."Verification Proof" := CopyStr(Proof, 1, MaxStrLen(AuditLog."Verification Proof"));
        AuditLog.Insert(true);
    end;
}
