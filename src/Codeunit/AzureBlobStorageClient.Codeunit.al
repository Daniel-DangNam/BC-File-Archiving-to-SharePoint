namespace APSS.FileArchiving;

using Microsoft.EServices.EDocument;
using Microsoft.Foundation.Attachment;
using System.Environment;
using System.Text;
using System.Utilities;

codeunit 50141 "Azure Blob Storage Client"
{
    var
        SasTokenStorageKeyLbl: Label 'BLOB_ARCHIVE_SAS_TOKEN', Locked = true;
        BlobItemUrlLbl: Label 'https://%1.blob.core.windows.net/%2/%3', Locked = true, Comment = '%1 = Storage Account, %2 = Container, %3 = Path';
        BlockUploadUrlLbl: Label 'https://%1.blob.core.windows.net/%2/%3?comp=block&blockid=%4', Locked = true;
        BlockListUrlLbl: Label 'https://%1.blob.core.windows.net/%2/%3?comp=blocklist', Locked = true;
        ContainerTestUrlLbl: Label 'https://%1.blob.core.windows.net/%2?restype=container&comp=list&maxresults=1', Locked = true;
        ApiVersionLbl: Label '2023-11-03', Locked = true;
        SetupNotConfiguredErr: Label 'Azure Blob Archive Setup is not configured. Please fill in Storage Account Name, Container Name, and SAS Token.';
        EnvGuardSandboxErr: Label 'Security Guard: Sandbox environment is blocked from connecting to Production container "%1".', Comment = '%1 = Container Name';
        EnvGuardProdErr: Label 'Security Guard: Production environment is blocked from connecting to Dev container "%1".', Comment = '%1 = Container Name';
        SizeMismatchErr: Label 'Size verification mismatch! Local size: %1 bytes, Azure Blob size: %2 bytes.', Comment = '%1 = Local size, %2 = Azure Blob size';
        AuditUploadStartedMsg: Label 'Upload started for file %1 to Azure Blob (Size: %2 bytes).', Comment = '%1 = File name, %2 = File size';
        AuditVerifySuccessMsg: Label 'Upload and verification succeeded on Azure Blob. Full URL: %1', Comment = '%1 = Blob URL';
        AuditVerifyProofTxt: Label 'ETag: %1, Size: %2, Content-MD5: %3', Comment = '%1 = ETag, %2 = Size, %3 = MD5';
        SourceBinaryNotFoundErr: Label 'Source attachment binary could not be found or read.';
        TestConnSuccessMsg: Label 'Connection successful!\Connected to Azure Blob Storage Container: "%1" in Account: "%2".', Comment = '%1 = Container Name, %2 = Storage Account';
        TestConnFailedErr: Label 'Azure Blob connection test failed. HTTP Status: %1, Details: %2', Comment = '%1 = HTTP Status Code, %2 = Details';
        BatchSummaryMsg: Label 'Batch processing completed. %1 of %2 files uploaded and verified successfully to Azure Blob.', Comment = '%1 = Success count, %2 = Total count';
        UploadFailedErr: Label 'Upload failed (HTTP %1): %2', Comment = '%1 = Status, %2 = Details';
        BlockUploadFailedErr: Label 'Block %1 failed (HTTP %2): %3', Comment = '%1 = Index, %2 = Status, %3 = Details';
        CommitBlockListFailedErr: Label 'Commit BlockList failed (HTTP %1): %2', Comment = '%1 = Status, %2 = Details';
        HeadVerifyFailedErr: Label 'HEAD verify failed (HTTP %1): %2', Comment = '%1 = Status, %2 = Details';

    procedure TestConnection(var ArchiveSetup: Record "Archive Setup"): Boolean
    var
        Client: HttpClient;
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        Headers: HttpHeaders;
        Url: Text;
        ResponseText: Text;
        SasToken: Text;
    begin
        if (ArchiveSetup."Storage Account Name" = '') or (ArchiveSetup."Container Name" = '') then
            Error(SetupNotConfiguredErr);

        ValidateEnvironmentGuard(ArchiveSetup);

        if not GetSasToken(SasToken) then
            Error(SetupNotConfiguredErr);

        Url := StrSubstNo(ContainerTestUrlLbl, ArchiveSetup."Storage Account Name", ArchiveSetup."Container Name");
        Url := AppendSasToken(Url, SasToken);
        Request.SetRequestUri(Url);
        Request.Method := 'GET';
        Request.GetHeaders(Headers);
        Headers.Add('x-ms-version', ApiVersionLbl);

        if not Client.Send(Request, Response) then
            Error(TestConnFailedErr, Response.HttpStatusCode(), 'Network request failed');

        Response.Content.ReadAs(ResponseText);

        if not Response.IsSuccessStatusCode() then begin
            ArchiveSetup."Is Configured" := false;
            ArchiveSetup.Modify(true);
            Error(TestConnFailedErr, Response.HttpStatusCode(), ResponseText);
        end;

        ArchiveSetup."Is Configured" := true;
        ArchiveSetup.Modify(true);

        Message(TestConnSuccessMsg, ArchiveSetup."Container Name", ArchiveSetup."Storage Account Name");
        exit(true);
    end;

    procedure ProcessQueueEntry(var QueueEntry: Record "Archive Queue Entry"): Boolean
    var
        ArchiveSetup: Record "Archive Setup";
        FileInStream: InStream;
        SanitizedPath: Text;
        UploadSuccess: Boolean;
        FullBlobUrl: Text[1000];
        ETag: Text[150];
        ContentMD5: Text[64];
        ReturnedSize: BigInteger;
        ErrorMsg: Text;
    begin
        if not ArchiveSetup.Get() then
            Error(SetupNotConfiguredErr);

        if (ArchiveSetup."Storage Account Name" = '') or (ArchiveSetup."Container Name" = '') then
            Error(SetupNotConfiguredErr);

        ValidateEnvironmentGuard(ArchiveSetup);

        if not GetSourceFileInStream(QueueEntry, FileInStream) then begin
            RecordQueueError(QueueEntry, SourceBinaryNotFoundErr);
            exit(false);
        end;

        SanitizedPath := BuildSanitizedPath(ArchiveSetup."Base Folder Path", QueueEntry);
        QueueEntry."Blob Relative Path" := CopyStr(SanitizedPath, 1, MaxStrLen(QueueEntry."Blob Relative Path"));
        QueueEntry."Archive Status" := QueueEntry."Archive Status"::Uploading;
        QueueEntry."Uploaded DateTime" := CurrentDateTime();
        QueueEntry.Modify(false);

        RecordAuditLog(QueueEntry, Enum::"Archive Audit Action"::UploadStarted, 'Uploading', StrSubstNo(AuditUploadStartedMsg, QueueEntry."File Name", QueueEntry."Original File Size (Bytes)"), '');

        // Upload execution: <= 4 MB uses Put Blob, > 4 MB uses Put Block / Put Block List
        if QueueEntry."Original File Size (Bytes)" <= 4194304 then
            UploadSuccess := ExecutePutBlob(ArchiveSetup, QueueEntry, SanitizedPath, FileInStream, FullBlobUrl, ETag, ContentMD5, ErrorMsg)
        else
            UploadSuccess := ExecutePutBlockList(ArchiveSetup, QueueEntry, SanitizedPath, FileInStream, QueueEntry."Original File Size (Bytes)", FullBlobUrl, ETag, ErrorMsg);

        if not UploadSuccess then begin
            RecordQueueError(QueueEntry, ErrorMsg);
            exit(false);
        end;

        // Two-way byte-exact verification via HEAD Blob
        if not VerifyBlobUpload(ArchiveSetup, SanitizedPath, ReturnedSize, ETag, ContentMD5, ErrorMsg) then begin
            RecordQueueError(QueueEntry, ErrorMsg);
            exit(false);
        end;

        if ReturnedSize <> QueueEntry."Original File Size (Bytes)" then begin
            RecordQueueError(QueueEntry, StrSubstNo(SizeMismatchErr, QueueEntry."Original File Size (Bytes)", ReturnedSize));
            exit(false);
        end;

        // Mark verified & link mapping
        QueueEntry."Archive Status" := QueueEntry."Archive Status"::Verified;
        QueueEntry."Purge Status" := QueueEntry."Purge Status"::NotEligible; // Hard-Locked Purge
        QueueEntry."Verified DateTime" := CurrentDateTime();
        QueueEntry."Blob Full URL" := FullBlobUrl;
        QueueEntry."Blob ETag" := ETag;
        QueueEntry."Blob Content MD5" := ContentMD5;
        QueueEntry."Last Error Message" := '';
        QueueEntry.Modify(false);

        UpsertLinkMapping(QueueEntry);

        RecordAuditLog(
            QueueEntry,
            Enum::"Archive Audit Action"::VerifySucceeded,
            'Verified',
            StrSubstNo(AuditVerifySuccessMsg, FullBlobUrl),
            StrSubstNo(AuditVerifyProofTxt, ETag, ReturnedSize, ContentMD5));

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

    local procedure ExecutePutBlob(
        ArchiveSetup: Record "Archive Setup";
        QueueEntry: Record "Archive Queue Entry";
        SanitizedPath: Text;
        FileInStream: InStream;
        var OutFullUrl: Text[1000];
        var OutETag: Text[150];
        var OutMD5: Text[64];
        var OutErrorMsg: Text): Boolean
    var
        Client: HttpClient;
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        Headers: HttpHeaders;
        Content: HttpContent;
        Url: Text;
        ResponseText: Text;
        SasToken: Text;
        TierName: Text;
        ResponseHeaders: HttpHeaders;
        ContentHeaders: HttpHeaders;
        Values: array[1] of Text;
    begin
        if not GetSasToken(SasToken) then begin
            OutErrorMsg := SetupNotConfiguredErr;
            exit(false);
        end;

        OutFullUrl := CopyStr(StrSubstNo(BlobItemUrlLbl, ArchiveSetup."Storage Account Name", ArchiveSetup."Container Name", SanitizedPath), 1, 1000);
        Url := AppendSasToken(OutFullUrl, SasToken);

        Request.SetRequestUri(Url);
        Request.Method := 'PUT';

        Request.GetHeaders(Headers);
        Headers.Add('x-ms-blob-type', 'BlockBlob');
        Headers.Add('x-ms-version', ApiVersionLbl);
        Headers.Add('x-ms-blob-content-type', GetContentType(QueueEntry."File Extension"));

        TierName := Format(ArchiveSetup."Default Access Tier");
        if TierName <> '' then
            Headers.Add('x-ms-access-tier', TierName);

        Content.WriteFrom(FileInStream);
        Request.Content := Content;

        if not Client.Send(Request, Response) then begin
            OutErrorMsg := 'Network request failed sending blob to Azure.';
            exit(false);
        end;

        if not Response.IsSuccessStatusCode() then begin
            Response.Content.ReadAs(ResponseText);
            OutErrorMsg := CopyStr(StrSubstNo(UploadFailedErr, Response.HttpStatusCode(), ResponseText), 1, 250);
            exit(false);
        end;

        ResponseHeaders := Response.Headers;
        if ResponseHeaders.GetValues('ETag', Values) then
            OutETag := CopyStr(Values[1], 1, MaxStrLen(OutETag));

        Response.Content.GetHeaders(ContentHeaders);
        if ContentHeaders.GetValues('Content-MD5', Values) then
            OutMD5 := CopyStr(Values[1], 1, MaxStrLen(OutMD5));

        exit(true);
    end;

    local procedure ExecutePutBlockList(
        ArchiveSetup: Record "Archive Setup";
        QueueEntry: Record "Archive Queue Entry";
        SanitizedPath: Text;
        FileInStream: InStream;
        FileSize: BigInteger;
        var OutFullUrl: Text[1000];
        var OutETag: Text[150];
        var OutErrorMsg: Text): Boolean
    var
        TempBlob: Codeunit "Temp Blob";
        Base64Convert: Codeunit "Base64 Convert";
        Client: HttpClient;
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        Headers: HttpHeaders;
        Content: HttpContent;
        ChunkInStream: InStream;
        ChunkOutStream: OutStream;
        ResponseText: Text;
        SasToken: Text;
        BlockIdBase64: Text;
        BlockUrl: Text;
        BlockListUrl: Text;
        BlockListXml: Text;
        ChunkSizeBytes: Integer;
        CurrentChunkSize: Integer;
        BytesRemaining: BigInteger;
        BlockIndex: Integer;
        ResponseHeaders: HttpHeaders;
        Values: array[1] of Text;
    begin
        if not GetSasToken(SasToken) then begin
            OutErrorMsg := SetupNotConfiguredErr;
            exit(false);
        end;

        OutFullUrl := CopyStr(StrSubstNo(BlobItemUrlLbl, ArchiveSetup."Storage Account Name", ArchiveSetup."Container Name", SanitizedPath), 1, 1000);

        ChunkSizeBytes := ArchiveSetup."Chunk Size (MB)" * 1048576;
        if ChunkSizeBytes < 1048576 then
            ChunkSizeBytes := 4194304;

        BytesRemaining := FileSize;
        BlockIndex := 1;
        BlockListXml := '<?xml version="1.0" encoding="utf-8"?><BlockList>';

        while BytesRemaining > 0 do begin
            if BytesRemaining > ChunkSizeBytes then
                CurrentChunkSize := ChunkSizeBytes
            else
                CurrentChunkSize := BytesRemaining;

            BlockIdBase64 := Base64Convert.ToBase64(PadStr(Format(BlockIndex), 6, '0'));
            BlockListXml += '<Latest>' + BlockIdBase64 + '</Latest>';

            Clear(TempBlob);
            TempBlob.CreateOutStream(ChunkOutStream);
            CopyStream(ChunkOutStream, FileInStream, CurrentChunkSize);
            TempBlob.CreateInStream(ChunkInStream);

            BlockUrl := StrSubstNo(BlockUploadUrlLbl, ArchiveSetup."Storage Account Name", ArchiveSetup."Container Name", SanitizedPath, BlockIdBase64);
            BlockUrl := AppendSasToken(BlockUrl, SasToken);

            Clear(Client);
            Clear(Request);
            Request.SetRequestUri(BlockUrl);
            Request.Method := 'PUT';
            Request.GetHeaders(Headers);
            Headers.Add('x-ms-version', ApiVersionLbl);

            Clear(Content);
            Content.WriteFrom(ChunkInStream);
            Request.Content := Content;

            if not Client.Send(Request, Response) then begin
                OutErrorMsg := 'Network request failed uploading block ' + Format(BlockIndex);
                exit(false);
            end;

            if not Response.IsSuccessStatusCode() then begin
                Response.Content.ReadAs(ResponseText);
                OutErrorMsg := CopyStr(StrSubstNo(BlockUploadFailedErr, BlockIndex, Response.HttpStatusCode(), ResponseText), 1, 250);
                exit(false);
            end;

            BlockIndex += 1;
            BytesRemaining -= CurrentChunkSize;
        end;

        BlockListXml += '</BlockList>';

        // Commit Block List
        BlockListUrl := StrSubstNo(BlockListUrlLbl, ArchiveSetup."Storage Account Name", ArchiveSetup."Container Name", SanitizedPath);
        BlockListUrl := AppendSasToken(BlockListUrl, SasToken);
        Clear(Client);
        Clear(Request);
        Request.SetRequestUri(BlockListUrl);
        Request.Method := 'PUT';
        Request.GetHeaders(Headers);
        Headers.Add('x-ms-version', ApiVersionLbl);
        Headers.Add('x-ms-access-tier', Format(ArchiveSetup."Default Access Tier"));
        Headers.Add('x-ms-blob-content-type', GetContentType(QueueEntry."File Extension"));

        Clear(Content);
        Content.WriteFrom(BlockListXml);
        Content.GetHeaders(Headers);
        Headers.Remove('Content-Type');
        Headers.Add('Content-Type', 'application/xml');
        Request.Content := Content;

        if not Client.Send(Request, Response) then begin
            OutErrorMsg := 'Network request failed committing block list.';
            exit(false);
        end;

        if not Response.IsSuccessStatusCode() then begin
            Response.Content.ReadAs(ResponseText);
            OutErrorMsg := CopyStr(StrSubstNo(CommitBlockListFailedErr, Response.HttpStatusCode(), ResponseText), 1, 250);
            exit(false);
        end;

        ResponseHeaders := Response.Headers;
        if ResponseHeaders.GetValues('ETag', Values) then
            OutETag := CopyStr(Values[1], 1, MaxStrLen(OutETag));

        exit(true);
    end;

    local procedure VerifyBlobUpload(
        ArchiveSetup: Record "Archive Setup";
        SanitizedPath: Text;
        var OutSize: BigInteger;
        var OutETag: Text[150];
        var OutMD5: Text[64];
        var OutErrorMsg: Text): Boolean
    var
        Client: HttpClient;
        Request: HttpRequestMessage;
        Response: HttpResponseMessage;
        Headers: HttpHeaders;
        ResponseHeaders: HttpHeaders;
        ContentHeaders: HttpHeaders;
        Url: Text;
        ResponseText: Text;
        SasToken: Text;
        Values: array[1] of Text;
    begin
        if not GetSasToken(SasToken) then begin
            OutErrorMsg := SetupNotConfiguredErr;
            exit(false);
        end;

        Url := StrSubstNo(BlobItemUrlLbl, ArchiveSetup."Storage Account Name", ArchiveSetup."Container Name", SanitizedPath);
        Url := AppendSasToken(Url, SasToken);

        Request.SetRequestUri(Url);
        Request.Method := 'HEAD';
        Request.GetHeaders(Headers);
        Headers.Add('x-ms-version', ApiVersionLbl);

        if not Client.Send(Request, Response) then begin
            OutErrorMsg := 'Network request failed during HEAD verification.';
            exit(false);
        end;

        if not Response.IsSuccessStatusCode() then begin
            Response.Content.ReadAs(ResponseText);
            OutErrorMsg := CopyStr(StrSubstNo(HeadVerifyFailedErr, Response.HttpStatusCode(), ResponseText), 1, 250);
            exit(false);
        end;

        Response.Content.GetHeaders(ContentHeaders);
        if ContentHeaders.GetValues('Content-Length', Values) then
            Evaluate(OutSize, Values[1]);

        ResponseHeaders := Response.Headers;
        if ResponseHeaders.GetValues('ETag', Values) then
            OutETag := CopyStr(Values[1], 1, MaxStrLen(OutETag));

        if ContentHeaders.GetValues('Content-MD5', Values) then
            OutMD5 := CopyStr(Values[1], 1, MaxStrLen(OutMD5));

        exit(OutSize > 0);
    end;

    procedure GenerateTemporaryViewUrl(QueueEntry: Record "Archive Queue Entry"): Text
    var
        ArchiveSetup: Record "Archive Setup";
        SasToken: Text;
        Url: Text;
    begin
        if not ArchiveSetup.Get() then
            exit('');

        if not GetSasToken(SasToken) then
            exit(QueueEntry."Blob Full URL");

        Url := StrSubstNo(BlobItemUrlLbl, ArchiveSetup."Storage Account Name", ArchiveSetup."Container Name", QueueEntry."Blob Relative Path");
        exit(AppendSasToken(Url, SasToken));
    end;

    procedure SetSasToken(SasToken: Text)
    begin
        if SasToken = '' then begin
            if IsolatedStorage.Contains(SasTokenStorageKeyLbl, DataScope::Company) then
                IsolatedStorage.Delete(SasTokenStorageKeyLbl, DataScope::Company);
        end else
            IsolatedStorage.SetEncrypted(SasTokenStorageKeyLbl, SasToken, DataScope::Company);
    end;

    procedure HasSasToken(): Boolean
    begin
        exit(IsolatedStorage.Contains(SasTokenStorageKeyLbl, DataScope::Company));
    end;

    local procedure GetSasToken(var OutSasToken: Text): Boolean
    begin
        exit(IsolatedStorage.Get(SasTokenStorageKeyLbl, DataScope::Company, OutSasToken));
    end;

    local procedure AppendSasToken(BaseUrl: Text; SasToken: Text): Text
    var
        CleanToken: Text;
    begin
        CleanToken := CleanSasToken(SasToken);
        if CleanToken = '' then
            exit(BaseUrl);
        if BaseUrl.Contains('?') then
            exit(BaseUrl + '&' + CleanToken);
        exit(BaseUrl + '?' + CleanToken);
    end;

    local procedure CleanSasToken(SasToken: Text): Text
    begin
        while (SasToken <> '') and ((SasToken[1] = '?') or (SasToken[1] = '&')) do
            SasToken := CopyStr(SasToken, 2);
        exit(SasToken);
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
        Result := Result.Replace(' ', '_');
        exit(Result);
    end;

    local procedure GetContentType(Extension: Text): Text
    begin
        case Extension.ToLower() of
            'pdf':
                exit('application/pdf');
            'png':
                exit('image/png');
            'jpg', 'jpeg':
                exit('image/jpeg');
            'xlsx':
                exit('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
            'docx':
                exit('application/vnd.openxmlformats-officedocument.wordprocessingml.document');
            'txt':
                exit('text/plain');
            else
                exit('application/octet-stream');
        end;
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
            LinkMapping."Blob Full URL" := QueueEntry."Blob Full URL";
            LinkMapping."Blob Relative Path" := QueueEntry."Blob Relative Path";
            LinkMapping."Is Purged In BC" := false;
            LinkMapping."Archived DateTime" := CurrentDateTime();
            LinkMapping.Insert(true);
        end else begin
            LinkMapping."Source Table ID" := QueueEntry."Source Table ID";
            LinkMapping."Source Document No." := QueueEntry."Source Document No.";
            LinkMapping."Source Line No." := QueueEntry."Source Line No.";
            LinkMapping."File Name" := QueueEntry."File Name";
            LinkMapping."Blob Full URL" := QueueEntry."Blob Full URL";
            LinkMapping."Blob Relative Path" := QueueEntry."Blob Relative Path";
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

    local procedure ValidateEnvironmentGuard(ArchiveSetup: Record "Archive Setup")
    var
        EnvironmentInformation: Codeunit "Environment Information";
        ContainerLower: Text;
    begin
        ContainerLower := ArchiveSetup."Container Name".ToLower();
        if EnvironmentInformation.IsSandbox() then begin
            if ContainerLower.Contains('prod') then
                Error(EnvGuardSandboxErr, ArchiveSetup."Container Name");
        end else
            if ContainerLower.Contains('dev') then
                Error(EnvGuardProdErr, ArchiveSetup."Container Name");
    end;
}
