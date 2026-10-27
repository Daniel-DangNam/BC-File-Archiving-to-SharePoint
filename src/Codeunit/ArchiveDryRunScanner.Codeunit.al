namespace APSS.FileArchiving;

using Microsoft.EServices.EDocument;
using Microsoft.Foundation.Attachment;
using System.Environment;
using System.Security.Encryption;

codeunit 50140 "Archive Dry-Run Scanner"
{
    TableNo = "Archive Setup";

    trigger OnRun()
    begin
        RunDryRun(Rec, WorkDate(), false);
    end;

    procedure RunDryRun(ArchiveSetup: Record "Archive Setup"; CutOffDate: Date; ShowSummary: Boolean)
    var
        TotalFiles: Integer;
        TotalBytes: BigInteger;
    begin
        RunDryRunForCompany(ArchiveSetup, CopyStr(CompanyName(), 1, 30), CutOffDate, TotalFiles, TotalBytes);

        if ShowSummary then
            Message(SummaryMsg, TotalFiles, FormatBytes(TotalBytes), CutOffDate);
    end;

    procedure RunDryRunForCompany(
        ArchiveSetup: Record "Archive Setup";
        TargetCompany: Text[30];
        CutOffDate: Date;
        var OutTotalFiles: Integer;
        var OutTotalBytes: BigInteger)
    var
        AuditLog: Record "Archive Audit Log";
    begin
        OutTotalFiles := 0;
        OutTotalBytes := 0;

        ScanDocumentAttachments(ArchiveSetup, TargetCompany, CutOffDate, OutTotalFiles, OutTotalBytes);
        ScanIncomingDocAttachments(ArchiveSetup, TargetCompany, CutOffDate, OutTotalFiles, OutTotalBytes);

        // Record immutable audit entry
        AuditLog.Init();
        AuditLog."Log Entry No." := 0;
        AuditLog."Queue Entry No." := 0;
        AuditLog."Company Name" := TargetCompany;
        AuditLog."Event DateTime" := CurrentDateTime();
        AuditLog."User ID" := CopyStr(UserId(), 1, MaxStrLen(AuditLog."User ID"));
        AuditLog."Action Type" := AuditLog."Action Type"::DryRun;
        AuditLog."Old Status" := '';
        AuditLog."New Status" := 'Draft / Preview';
        AuditLog."Message" := CopyStr(StrSubstNo(PreviewLogMsg, OutTotalFiles, OutTotalBytes), 1, MaxStrLen(AuditLog."Message"));
        AuditLog."Verification Proof" := CopyStr(StrSubstNo(VerificationProofTxt, CutOffDate, ArchiveSetup."Cut-Off Date Rule"), 1, MaxStrLen(AuditLog."Verification Proof"));
        AuditLog.Insert(true);
    end;

    local procedure ScanDocumentAttachments(
        ArchiveSetup: Record "Archive Setup";
        TargetCompany: Text[30];
        CutOffDate: Date;
        var OutTotalFiles: Integer;
        var OutTotalBytes: BigInteger)
    var
        DocAttachment: Record "Document Attachment";
        QueueEntry: Record "Archive Queue Entry";
        TenantMedia: Record "Tenant Media";
        FileSize: BigInteger;
        DetKey: Text[128];
    begin
        DocAttachment.ChangeCompany(TargetCompany);
        DocAttachment.SetFilter("File Name", '<>%1', '');

        if DocAttachment.FindSet(false) then
            repeat
                if IsDocAttachmentEligible(DocAttachment, ArchiveSetup."Cut-Off Date Rule", CutOffDate) then begin
                    FileSize := 0;
                    if TenantMedia.Get(DocAttachment."Document Reference ID".MediaId()) then begin
                        TenantMedia.CalcFields(Content);
                        FileSize := TenantMedia.Content.Length();
                    end;

                    if FileSize > 0 then begin
                        DetKey := GenerateDeterministicKey(TargetCompany, Database::"Document Attachment", DocAttachment.SystemId, FileSize);

                        QueueEntry.SetCurrentKey("Deterministic Archive Key");
                        QueueEntry.SetRange("Deterministic Archive Key", DetKey);
                        if not QueueEntry.FindFirst() then begin
                            QueueEntry.Init();
                            QueueEntry."Entry No." := 0;
                            QueueEntry."Deterministic Archive Key" := DetKey;
                            QueueEntry."Company Name" := TargetCompany;
                            QueueEntry."Source Table ID" := Database::"Document Attachment";
                            QueueEntry."Attachment SystemId" := DocAttachment.SystemId;
                            QueueEntry."Source Document Type" := Format(DocAttachment."Document Type");
                            QueueEntry."Source Document No." := DocAttachment."No.";
                            QueueEntry."Source Line No." := DocAttachment."Line No.";
                            QueueEntry."Source Attachment ID" := DocAttachment.ID;
                            QueueEntry."File Name" := DocAttachment."File Name";
                            QueueEntry."File Extension" := DocAttachment."File Extension";
                            QueueEntry."Original File Size (Bytes)" := FileSize;
                            QueueEntry."Archive Status" := QueueEntry."Archive Status"::Draft;
                            QueueEntry."Purge Status" := QueueEntry."Purge Status"::NotEligible;
                            QueueEntry."Is Dry Run" := true;
                            QueueEntry."Queued DateTime" := CurrentDateTime();
                            QueueEntry.Insert(true);
                        end;

                        OutTotalFiles += 1;
                        OutTotalBytes += FileSize;
                    end;
                end;
            until DocAttachment.Next() = 0;
    end;

    local procedure ScanIncomingDocAttachments(
        ArchiveSetup: Record "Archive Setup";
        TargetCompany: Text[30];
        CutOffDate: Date;
        var OutTotalFiles: Integer;
        var OutTotalBytes: BigInteger)
    var
        IncDocAttachment: Record "Incoming Document Attachment";
        QueueEntry: Record "Archive Queue Entry";
        FileSize: BigInteger;
        DetKey: Text[128];
    begin
        IncDocAttachment.ChangeCompany(TargetCompany);

        if IncDocAttachment.FindSet(false) then
            repeat
                if IsIncomingDocEligible(IncDocAttachment, ArchiveSetup."Cut-Off Date Rule", CutOffDate) then begin
                    IncDocAttachment.CalcFields(Content);
                    FileSize := IncDocAttachment.Content.Length();

                    if FileSize > 0 then begin
                        DetKey := GenerateDeterministicKey(TargetCompany, Database::"Incoming Document Attachment", IncDocAttachment.SystemId, FileSize);

                        QueueEntry.SetCurrentKey("Deterministic Archive Key");
                        QueueEntry.SetRange("Deterministic Archive Key", DetKey);
                        if not QueueEntry.FindFirst() then begin
                            QueueEntry.Init();
                            QueueEntry."Entry No." := 0;
                            QueueEntry."Deterministic Archive Key" := DetKey;
                            QueueEntry."Company Name" := TargetCompany;
                            QueueEntry."Source Table ID" := Database::"Incoming Document Attachment";
                            QueueEntry."Attachment SystemId" := IncDocAttachment.SystemId;
                            QueueEntry."Source Document No." := IncDocAttachment."Document No.";
                            QueueEntry."Source Line No." := IncDocAttachment."Line No.";
                            QueueEntry."Source Attachment ID" := IncDocAttachment."Line No.";
                            QueueEntry."File Name" := IncDocAttachment.Name;
                            QueueEntry."File Extension" := IncDocAttachment."File Extension";
                            QueueEntry."Original File Size (Bytes)" := FileSize;
                            QueueEntry."Archive Status" := QueueEntry."Archive Status"::Draft;
                            QueueEntry."Purge Status" := QueueEntry."Purge Status"::NotEligible;
                            QueueEntry."Is Dry Run" := true;
                            QueueEntry."Queued DateTime" := CurrentDateTime();
                            QueueEntry.Insert(true);
                        end;

                        OutTotalFiles += 1;
                        OutTotalBytes += FileSize;
                    end;
                end;
            until IncDocAttachment.Next() = 0;
    end;

    local procedure IsDocAttachmentEligible(
        DocAttachment: Record "Document Attachment";
        CutOffRule: Option "Posting Date","Document Date","Attached Date";
        CutOffDate: Date): Boolean
    var
        AttachedDate: Date;
    begin
        if CutOffDate = 0D then
            exit(true);

        case CutOffRule of
            CutOffRule::"Attached Date":
                begin
                    AttachedDate := DT2Date(DocAttachment."Attached Date");
                    if AttachedDate = 0D then
                        exit(true);
                    exit(AttachedDate <= CutOffDate);
                end;
            else begin
                AttachedDate := DT2Date(DocAttachment."Attached Date");
                if AttachedDate = 0D then
                    exit(true);
                exit(AttachedDate <= CutOffDate);
            end;
        end;
    end;

    local procedure IsIncomingDocEligible(
        IncDocAttachment: Record "Incoming Document Attachment";
        CutOffRule: Option "Posting Date","Document Date","Attached Date";
        CutOffDate: Date): Boolean
    var
        TargetDate: Date;
    begin
        if CutOffDate = 0D then
            exit(true);

        case CutOffRule of
            CutOffRule::"Posting Date":
                TargetDate := IncDocAttachment."Posting Date";
            else
                TargetDate := DT2Date(IncDocAttachment."Created Date-Time");
        end;

        if TargetDate = 0D then
            TargetDate := IncDocAttachment."Posting Date";

        if TargetDate = 0D then
            exit(true);

        exit(TargetDate <= CutOffDate);
    end;

    local procedure GenerateDeterministicKey(
        TargetCompany: Text[30];
        SourceTableId: Integer;
        AttachmentSystemId: Guid;
        FileSize: BigInteger): Text[128]
    var
        CryptographyManagement: Codeunit "Cryptography Management";
        HashAlgorithmType: Option MD5,SHA1,SHA256,SHA384,SHA512;
        RawInput: Text;
    begin
        RawInput := TargetCompany + '_' + Format(SourceTableId) + '_' + Format(AttachmentSystemId) + '_' + Format(FileSize);
        exit(CopyStr(CryptographyManagement.GenerateHash(RawInput, HashAlgorithmType::SHA256), 1, 128));
    end;

    local procedure FormatBytes(Bytes: BigInteger): Text
    var
        MB: Decimal;
    begin
        MB := Bytes / 1048576;
        if MB < 1 then
            exit(StrSubstNo(SizeKBLbl, Bytes div 1024));
        exit(StrSubstNo(SizeMBLbl, Round(MB, 0.01)));
    end;

    var
        SummaryMsg: Label 'Preview / Dry-Run hoàn tất:\- Tổng số tệp thỏa điều kiện: %1\- Tổng dung lượng dự kiến giải phóng: %2\- Ngày Cut-off: %3\(Lưu ý: Chế độ Dry-Run chỉ quét thống kê, không upload và không xóa bất kỳ dữ liệu nào trên BC).', Comment = '%1 = File count, %2 = Formatted size, %3 = Cut-off date';
        PreviewLogMsg: Label 'Preview scan completed: %1 eligible files, %2 bytes evaluated.', Comment = '%1 = File count, %2 = Bytes';
        VerificationProofTxt: Label 'Cut-Off Date: %1, Rule: %2', Comment = '%1 = Date, %2 = Rule';
        SizeKBLbl: Label '%1 KB', Comment = '%1 = Kilobytes';
        SizeMBLbl: Label '%1 MB', Comment = '%1 = Megabytes';
}
