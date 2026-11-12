namespace APSS.FileArchiving;

using Microsoft.EServices.EDocument;
using Microsoft.Foundation.Attachment;
using Microsoft.Purchases.Document;
using Microsoft.Purchases.History;
using Microsoft.Sales.Document;
using Microsoft.Sales.History;
using System.Environment;
using System.Reflection;
using System.Security.Encryption;
using System.Utilities;

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
        SkippedEmptyDate: Integer;
    begin
        RunDryRunForCompany(ArchiveSetup, CopyStr(CompanyName(), 1, 30), CutOffDate, TotalFiles, TotalBytes, SkippedEmptyDate);

        if ShowSummary then
            Message(SummaryMsg, TotalFiles, FormatBytes(TotalBytes), CutOffDate, SkippedEmptyDate);
    end;

    procedure RunDryRunForCompany(
        ArchiveSetup: Record "Archive Setup";
        TargetCompany: Text[30];
        CutOffDate: Date;
        var OutTotalFiles: Integer;
        var OutTotalBytes: BigInteger;
        var OutSkippedEmptyDate: Integer)
    var
        AuditLog: Record "Archive Audit Log";
        CutOffRuleText: Text[50];
    begin
        OutTotalFiles := 0;
        OutTotalBytes := 0;
        OutSkippedEmptyDate := 0;

        ScanDocumentAttachments(ArchiveSetup, TargetCompany, CutOffDate, OutTotalFiles, OutTotalBytes, OutSkippedEmptyDate);
        ScanIncomingDocAttachments(ArchiveSetup, TargetCompany, CutOffDate, OutTotalFiles, OutTotalBytes, OutSkippedEmptyDate);

        CutOffRuleText := Format(ArchiveSetup."Cut-Off Date Rule");

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
        AuditLog."Message" := CopyStr(StrSubstNo(PreviewLogMsg, OutTotalFiles, OutTotalBytes, OutSkippedEmptyDate), 1, MaxStrLen(AuditLog."Message"));
        AuditLog."Verification Proof" := CopyStr(StrSubstNo(VerificationProofTxt, CutOffDate, CutOffRuleText), 1, MaxStrLen(AuditLog."Verification Proof"));
        AuditLog.Insert(true);
    end;

    local procedure ScanDocumentAttachments(
        ArchiveSetup: Record "Archive Setup";
        TargetCompany: Text[30];
        CutOffDate: Date;
        var OutTotalFiles: Integer;
        var OutTotalBytes: BigInteger;
        var OutSkippedEmptyDate: Integer)
    var
        DocAttachment: Record "Document Attachment";
        QueueEntry: Record "Archive Queue Entry";
        TenantMedia: Record "Tenant Media";
        FileSize: BigInteger;
        DetKey: Text[128];
        EvalDateField: Text[50];
        EvalDateValue: Date;
    begin
        DocAttachment.ChangeCompany(TargetCompany);
        DocAttachment.SetFilter("File Name", '<>%1', '');

        if DocAttachment.FindSet(false) then
            repeat
                if IsDocAttachmentEligible(DocAttachment, TargetCompany, ArchiveSetup."Cut-Off Date Rule", CutOffDate, EvalDateField, EvalDateValue) then begin
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
                            QueueEntry."Evaluated Date Field" := EvalDateField;
                            QueueEntry."Evaluated Date Value" := EvalDateValue;
                            QueueEntry."Archive Status" := QueueEntry."Archive Status"::Draft;
                            QueueEntry."Purge Status" := QueueEntry."Purge Status"::NotEligible;
                            QueueEntry."Is Dry Run" := true;
                            QueueEntry."Queued DateTime" := CurrentDateTime();
                            QueueEntry.Insert(true);
                        end;

                        OutTotalFiles += 1;
                        OutTotalBytes += FileSize;
                    end;
                end else
                    if (CutOffDate <> 0D) and (EvalDateValue = 0D) then
                        OutSkippedEmptyDate += 1;
            until DocAttachment.Next() = 0;
    end;

    local procedure ScanIncomingDocAttachments(
        ArchiveSetup: Record "Archive Setup";
        TargetCompany: Text[30];
        CutOffDate: Date;
        var OutTotalFiles: Integer;
        var OutTotalBytes: BigInteger;
        var OutSkippedEmptyDate: Integer)
    var
        IncDocAttachment: Record "Incoming Document Attachment";
        QueueEntry: Record "Archive Queue Entry";
        FileSize: BigInteger;
        DetKey: Text[128];
        EvalDateField: Text[50];
        EvalDateValue: Date;
    begin
        IncDocAttachment.ChangeCompany(TargetCompany);

        if IncDocAttachment.FindSet(false) then
            repeat
                if IsIncomingDocEligible(IncDocAttachment, TargetCompany, ArchiveSetup."Cut-Off Date Rule", CutOffDate, EvalDateField, EvalDateValue) then begin
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
                            QueueEntry."Evaluated Date Field" := EvalDateField;
                            QueueEntry."Evaluated Date Value" := EvalDateValue;
                            QueueEntry."Archive Status" := QueueEntry."Archive Status"::Draft;
                            QueueEntry."Purge Status" := QueueEntry."Purge Status"::NotEligible;
                            QueueEntry."Is Dry Run" := true;
                            QueueEntry."Queued DateTime" := CurrentDateTime();
                            QueueEntry.Insert(true);
                        end;

                        OutTotalFiles += 1;
                        OutTotalBytes += FileSize;
                    end;
                end else
                    if (CutOffDate <> 0D) and (EvalDateValue = 0D) then
                        OutSkippedEmptyDate += 1;
            until IncDocAttachment.Next() = 0;
    end;

    local procedure IsDocAttachmentEligible(
        DocAttachment: Record "Document Attachment";
        TargetCompany: Text[30];
        CutOffRule: Option "Posting Date","Document Date";
        CutOffDate: Date;
        var OutDateField: Text[50];
        var OutDateValue: Date): Boolean
    begin
        GetDocAttachmentDate(DocAttachment, TargetCompany, CutOffRule, OutDateField, OutDateValue);

        if CutOffDate = 0D then
            exit(true);

        // Strict No-Fallback: If the date is empty, skip record immediately
        if OutDateValue = 0D then
            exit(false);

        exit(OutDateValue <= CutOffDate);
    end;

    local procedure GetDocAttachmentDate(
        DocAttachment: Record "Document Attachment";
        TargetCompany: Text[30];
        CutOffRule: Option "Posting Date","Document Date";
        var OutDateField: Text[50];
        var OutDateValue: Date)
    var
        SalesHeader: Record "Sales Header";
        SalesInvHeader: Record "Sales Invoice Header";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        PurchHeader: Record "Purchase Header";
        PurchInvHeader: Record "Purch. Inv. Header";
        PurchCrMemoHdr: Record "Purch. Cr. Memo Hdr.";
    begin
        OutDateValue := 0D;

        if CutOffRule = CutOffRule::"Posting Date" then
            OutDateField := 'Posting Date'
        else
            OutDateField := 'Document Date';

        case DocAttachment."Table ID" of
            Database::"Sales Header":
                begin
                    SalesHeader.ChangeCompany(TargetCompany);
                    if SalesHeader.Get(DocAttachment."Document Type", DocAttachment."No.") then
                        if CutOffRule = CutOffRule::"Posting Date" then
                            OutDateValue := SalesHeader."Posting Date"
                        else
                            OutDateValue := SalesHeader."Document Date";
                end;
            Database::"Sales Invoice Header":
                begin
                    SalesInvHeader.ChangeCompany(TargetCompany);
                    if SalesInvHeader.Get(DocAttachment."No.") then
                        if CutOffRule = CutOffRule::"Posting Date" then
                            OutDateValue := SalesInvHeader."Posting Date"
                        else
                            OutDateValue := SalesInvHeader."Document Date";
                end;
            Database::"Sales Cr.Memo Header":
                begin
                    SalesCrMemoHeader.ChangeCompany(TargetCompany);
                    if SalesCrMemoHeader.Get(DocAttachment."No.") then
                        if CutOffRule = CutOffRule::"Posting Date" then
                            OutDateValue := SalesCrMemoHeader."Posting Date"
                        else
                            OutDateValue := SalesCrMemoHeader."Document Date";
                end;
            Database::"Purchase Header":
                begin
                    PurchHeader.ChangeCompany(TargetCompany);
                    if PurchHeader.Get(DocAttachment."Document Type", DocAttachment."No.") then
                        if CutOffRule = CutOffRule::"Posting Date" then
                            OutDateValue := PurchHeader."Posting Date"
                        else
                            OutDateValue := PurchHeader."Document Date";
                end;
            Database::"Purch. Inv. Header":
                begin
                    PurchInvHeader.ChangeCompany(TargetCompany);
                    if PurchInvHeader.Get(DocAttachment."No.") then
                        if CutOffRule = CutOffRule::"Posting Date" then
                            OutDateValue := PurchInvHeader."Posting Date"
                        else
                            OutDateValue := PurchInvHeader."Document Date";
                end;
            Database::"Purch. Cr. Memo Hdr.":
                begin
                    PurchCrMemoHdr.ChangeCompany(TargetCompany);
                    if PurchCrMemoHdr.Get(DocAttachment."No.") then
                        if CutOffRule = CutOffRule::"Posting Date" then
                            OutDateValue := PurchCrMemoHdr."Posting Date"
                        else
                            OutDateValue := PurchCrMemoHdr."Document Date";
                end;
        end;
    end;

    local procedure IsIncomingDocEligible(
        IncDocAttachment: Record "Incoming Document Attachment";
        TargetCompany: Text[30];
        CutOffRule: Option "Posting Date","Document Date";
        CutOffDate: Date;
        var OutDateField: Text[50];
        var OutDateValue: Date): Boolean
    var
        IncomingDocument: Record "Incoming Document";
    begin
        OutDateValue := 0D;

        if CutOffRule = CutOffRule::"Posting Date" then begin
            OutDateField := 'Posting Date';
            OutDateValue := IncDocAttachment."Posting Date";
            if OutDateValue = 0D then begin
                IncomingDocument.ChangeCompany(TargetCompany);
                if IncomingDocument.Get(IncDocAttachment."Incoming Document Entry No.") then
                    OutDateValue := IncomingDocument."Posting Date";
            end;
        end else begin
            OutDateField := 'Document Date';
            IncomingDocument.ChangeCompany(TargetCompany);
            if IncomingDocument.Get(IncDocAttachment."Incoming Document Entry No.") then
                OutDateValue := IncomingDocument."Document Date";
        end;

        if CutOffDate = 0D then
            exit(true);

        // Strict No-Fallback: If target date is empty, skip immediately
        if OutDateValue = 0D then
            exit(false);

        exit(OutDateValue <= CutOffDate);
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

    procedure ExportSkippedBreakdownCsv(ArchiveSetup: Record "Archive Setup"; CutOffDate: Date)
    var
        DocAttachment: Record "Document Attachment";
        IncDocAttachment: Record "Incoming Document Attachment";
        IncomingDocument: Record "Incoming Document";
        SalesHeader: Record "Sales Header";
        SalesInvHeader: Record "Sales Invoice Header";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        PurchHeader: Record "Purchase Header";
        PurchInvHeader: Record "Purch. Inv. Header";
        PurchCrMemoHdr: Record "Purch. Cr. Memo Hdr.";
        AllObjWithCaption: Record AllObjWithCaption;
        TempBlob: Codeunit "Temp Blob";
        CsvOutStream: OutStream;
        CsvInStream: InStream;
        TargetCompany: Text[30];
        EvalDateField: Text[50];
        EvalDateValue: Date;
        GroupKey: Text;
        ReasonText: Text;
        TableNameText: Text;
        CountByGroup: Dictionary of [Text, Integer];
        TableIdByGroup: Dictionary of [Text, Integer];
        DocTypeByGroup: Dictionary of [Text, Text];
        ReasonByGroup: Dictionary of [Text, Text];
        GroupKeys: List of [Text];
        TotalSkipped: Integer;
        TargetTableId: Integer;
        FileName: Text;
        CrLf: Text[2];
    begin
        TargetCompany := CopyStr(CompanyName(), 1, 30);
        CrLf[1] := 13;
        CrLf[2] := 10;

        // 1. Evaluate Document Attachment (Table 1173)
        DocAttachment.ChangeCompany(TargetCompany);
        DocAttachment.SetFilter("File Name", '<>%1', '');
        if DocAttachment.FindSet(false) then
            repeat
                if not IsDocAttachmentEligible(DocAttachment, TargetCompany, ArchiveSetup."Cut-Off Date Rule", CutOffDate, EvalDateField, EvalDateValue) then
                    if (CutOffDate <> 0D) and (EvalDateValue = 0D) then begin
                        ReasonText := GetDocAttachmentSkipReason(
                            DocAttachment, TargetCompany,
                            SalesHeader, SalesInvHeader, SalesCrMemoHeader,
                            PurchHeader, PurchInvHeader, PurchCrMemoHdr);
                        GroupKey := '1173|' + Format(DocAttachment."Table ID") + '|' + Format(DocAttachment."Document Type") + '|' + ReasonText;
                        if not CountByGroup.ContainsKey(GroupKey) then begin
                            GroupKeys.Add(GroupKey);
                            CountByGroup.Add(GroupKey, 0);
                            TableIdByGroup.Add(GroupKey, DocAttachment."Table ID");
                            DocTypeByGroup.Add(GroupKey, Format(DocAttachment."Document Type"));
                            ReasonByGroup.Add(GroupKey, ReasonText);
                        end;
                        CountByGroup.Set(GroupKey, CountByGroup.Get(GroupKey) + 1);
                        TotalSkipped += 1;
                    end;
            until DocAttachment.Next() = 0;

        // 2. Evaluate Incoming Document Attachment (Table 133)
        IncDocAttachment.ChangeCompany(TargetCompany);
        if IncDocAttachment.FindSet(false) then
            repeat
                if not IsIncomingDocEligible(IncDocAttachment, TargetCompany, ArchiveSetup."Cut-Off Date Rule", CutOffDate, EvalDateField, EvalDateValue) then
                    if (CutOffDate <> 0D) and (EvalDateValue = 0D) then begin
                        IncomingDocument.ChangeCompany(TargetCompany);
                        if IncomingDocument.Get(IncDocAttachment."Incoming Document Entry No.") then begin
                            if IncomingDocument.Posted then
                                ReasonText := 'Incoming Document Posted=True but Posting/Document Date is blank'
                            else
                                ReasonText := 'Incoming Document Unposted (Posted=False) and Posting/Document Date is blank';
                        end else
                            ReasonText := 'Orphaned Incoming Document Attachment (Header Entry No. not found in Table 130)';

                        GroupKey := '133|130|IncomingDoc|' + ReasonText;
                        if not CountByGroup.ContainsKey(GroupKey) then begin
                            GroupKeys.Add(GroupKey);
                            CountByGroup.Add(GroupKey, 0);
                            TableIdByGroup.Add(GroupKey, Database::"Incoming Document");
                            DocTypeByGroup.Add(GroupKey, 'Incoming Document');
                            ReasonByGroup.Add(GroupKey, ReasonText);
                        end;
                        CountByGroup.Set(GroupKey, CountByGroup.Get(GroupKey) + 1);
                        TotalSkipped += 1;
                    end;
            until IncDocAttachment.Next() = 0;

        // 3. Generate CSV
        TempBlob.CreateOutStream(CsvOutStream, TextEncoding::UTF8);
        CsvOutStream.WriteText('Company,Attachment Table ID,Target Source Table ID,Target Source Table Name,Document Type,Skip Reason,Skipped File Count' + CrLf);

        foreach GroupKey in GroupKeys do begin
            TargetTableId := TableIdByGroup.Get(GroupKey);
            TableNameText := 'Unknown Table';
            if AllObjWithCaption.Get(AllObjWithCaption."Object Type"::Table, TargetTableId) then
                TableNameText := AllObjWithCaption."Object Name";

            if GroupKey.StartsWith('1173|') then
                CsvOutStream.WriteText(
                    StrSubstNo(CsvRow1173Lbl,
                        TargetCompany,
                        TargetTableId,
                        TableNameText,
                        DocTypeByGroup.Get(GroupKey),
                        ReasonByGroup.Get(GroupKey),
                        CountByGroup.Get(GroupKey)) + CrLf)
            else
                CsvOutStream.WriteText(
                    StrSubstNo(CsvRow133Lbl,
                        TargetCompany,
                        TargetTableId,
                        TableNameText,
                        DocTypeByGroup.Get(GroupKey),
                        ReasonByGroup.Get(GroupKey),
                        CountByGroup.Get(GroupKey)) + CrLf);
        end;

        CsvOutStream.WriteText(StrSubstNo(CsvRowTotalLbl, TargetCompany, TotalSkipped) + CrLf);

        TempBlob.CreateInStream(CsvInStream, TextEncoding::UTF8);
        FileName := StrSubstNo(SkippedCsvFileNameLbl, DelChr(TargetCompany, '=', ' /\&*'), Format(Today(), 0, '<Year4><Month,2><Day,2>'));
        DownloadFromStream(CsvInStream, 'Export Skipped Files Breakdown', '', 'CSV Files (*.csv)|*.csv', FileName);
    end;

    local procedure GetDocAttachmentSkipReason(
        DocAttachment: Record "Document Attachment";
        TargetCompany: Text[30];
        var SalesHeader: Record "Sales Header";
        var SalesInvHeader: Record "Sales Invoice Header";
        var SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        var PurchHeader: Record "Purchase Header";
        var PurchInvHeader: Record "Purch. Inv. Header";
        var PurchCrMemoHdr: Record "Purch. Cr. Memo Hdr."): Text
    begin
        case DocAttachment."Table ID" of
            Database::"Sales Header":
                begin
                    SalesHeader.ChangeCompany(TargetCompany);
                    if SalesHeader.Get(DocAttachment."Document Type", DocAttachment."No.") then
                        exit('Unposted/Open Sales Header with blank date')
                    else
                        exit('Orphaned Attachment (Sales Header record not found)');
                end;
            Database::"Sales Invoice Header":
                begin
                    SalesInvHeader.ChangeCompany(TargetCompany);
                    if SalesInvHeader.Get(DocAttachment."No.") then
                        exit('Posted Sales Invoice with blank date')
                    else
                        exit('Orphaned Attachment (Sales Invoice Header not found)');
                end;
            Database::"Sales Cr.Memo Header":
                begin
                    SalesCrMemoHeader.ChangeCompany(TargetCompany);
                    if SalesCrMemoHeader.Get(DocAttachment."No.") then
                        exit('Posted Sales Cr.Memo with blank date')
                    else
                        exit('Orphaned Attachment (Sales Cr.Memo Header not found)');
                end;
            Database::"Purchase Header":
                begin
                    PurchHeader.ChangeCompany(TargetCompany);
                    if PurchHeader.Get(DocAttachment."Document Type", DocAttachment."No.") then
                        exit('Unposted/Open Purchase Header with blank date')
                    else
                        exit('Orphaned Attachment (Purchase Header record not found)');
                end;
            Database::"Purch. Inv. Header":
                begin
                    PurchInvHeader.ChangeCompany(TargetCompany);
                    if PurchInvHeader.Get(DocAttachment."No.") then
                        exit('Posted Purchase Invoice with blank date')
                    else
                        exit('Orphaned Attachment (Purch. Inv. Header not found)');
                end;
            Database::"Purch. Cr. Memo Hdr.":
                begin
                    PurchCrMemoHdr.ChangeCompany(TargetCompany);
                    if PurchCrMemoHdr.Get(DocAttachment."No.") then
                        exit('Posted Purchase Cr.Memo with blank date')
                    else
                        exit('Orphaned Attachment (Purch. Cr. Memo Hdr. not found)');
                end;
            else
                exit('Unsupported Source Table ID (Not mapped in Sales/Purchase date evaluator)');
        end;
    end;

    procedure ExportDateFieldBreakdownCsv(ArchiveSetup: Record "Archive Setup"; CutOffDate: Date)
    var
        DocAttachment: Record "Document Attachment";
        IncDocAttachment: Record "Incoming Document Attachment";
        IncomingDocument: Record "Incoming Document";
        SalesHeader: Record "Sales Header";
        SalesInvHeader: Record "Sales Invoice Header";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        PurchHeader: Record "Purchase Header";
        PurchInvHeader: Record "Purch. Inv. Header";
        PurchCrMemoHdr: Record "Purch. Cr. Memo Hdr.";
        TenantMedia: Record "Tenant Media";
        AllObjWithCaption: Record AllObjWithCaption;
        TempBlob: Codeunit "Temp Blob";
        CsvOutStream: OutStream;
        CsvInStream: InStream;
        TargetCompany: Text[30];
        EvalDateField: Text[50];
        EvalDateValue: Date;
        GroupKey: Text;
        TableNameText: Text;
        HasDocDate: Boolean;
        HasOrderDate: Boolean;
        HasAttachCreated: Boolean;
        HasHeaderCreated: Boolean;
        FileSize: BigInteger;
        CountByGroup: Dictionary of [Text, Integer];
        BytesByGroup: Dictionary of [Text, BigInteger];
        TableIdByGroup: Dictionary of [Text, Integer];
        DocTypeByGroup: Dictionary of [Text, Text];
        HasDocDateByGroup: Dictionary of [Text, Boolean];
        HasOrderDateByGroup: Dictionary of [Text, Boolean];
        HasAttachCreatedByGroup: Dictionary of [Text, Boolean];
        HasHeaderCreatedByGroup: Dictionary of [Text, Boolean];
        GroupKeys: List of [Text];
        TotalSkipped: Integer;
        TotalBytes: BigInteger;
        TargetTableId: Integer;
        FileName: Text;
        CrLf: Text[2];
        DecMB: Decimal;
        TotalDecMB: Decimal;
    begin
        TargetCompany := CopyStr(CompanyName(), 1, 30);
        CrLf[1] := 13;
        CrLf[2] := 10;

        // 1. Scan Table 1173 (Document Attachment)
        DocAttachment.ChangeCompany(TargetCompany);
        DocAttachment.SetFilter("File Name", '<>%1', '');
        if DocAttachment.FindSet(false) then
            repeat
                if not IsDocAttachmentEligible(DocAttachment, TargetCompany, ArchiveSetup."Cut-Off Date Rule", CutOffDate, EvalDateField, EvalDateValue) then
                    if (CutOffDate <> 0D) and (EvalDateValue = 0D) then begin
                        FileSize := 0;
                        if TenantMedia.Get(DocAttachment."Document Reference ID".MediaId()) then begin
                            TenantMedia.CalcFields(Content);
                            FileSize := TenantMedia.Content.Length();
                        end;

                        HasDocDate := false;
                        HasOrderDate := false;
                        HasAttachCreated := DocAttachment.SystemCreatedAt <> 0DT;
                        HasHeaderCreated := false;

                        case DocAttachment."Table ID" of
                            Database::"Sales Header":
                                begin
                                    SalesHeader.ChangeCompany(TargetCompany);
                                    if SalesHeader.Get(DocAttachment."Document Type", DocAttachment."No.") then begin
                                        HasDocDate := SalesHeader."Document Date" <> 0D;
                                        HasOrderDate := SalesHeader."Order Date" <> 0D;
                                        HasHeaderCreated := SalesHeader.SystemCreatedAt <> 0DT;
                                    end;
                                end;
                            Database::"Sales Invoice Header":
                                begin
                                    SalesInvHeader.ChangeCompany(TargetCompany);
                                    if SalesInvHeader.Get(DocAttachment."No.") then begin
                                        HasDocDate := SalesInvHeader."Document Date" <> 0D;
                                        HasOrderDate := SalesInvHeader."Order Date" <> 0D;
                                        HasHeaderCreated := SalesInvHeader.SystemCreatedAt <> 0DT;
                                    end;
                                end;
                            Database::"Sales Cr.Memo Header":
                                begin
                                    SalesCrMemoHeader.ChangeCompany(TargetCompany);
                                    if SalesCrMemoHeader.Get(DocAttachment."No.") then begin
                                        HasDocDate := SalesCrMemoHeader."Document Date" <> 0D;
                                        HasHeaderCreated := SalesCrMemoHeader.SystemCreatedAt <> 0DT;
                                    end;
                                end;
                            Database::"Purchase Header":
                                begin
                                    PurchHeader.ChangeCompany(TargetCompany);
                                    if PurchHeader.Get(DocAttachment."Document Type", DocAttachment."No.") then begin
                                        HasDocDate := PurchHeader."Document Date" <> 0D;
                                        HasOrderDate := PurchHeader."Order Date" <> 0D;
                                        HasHeaderCreated := PurchHeader.SystemCreatedAt <> 0DT;
                                    end;
                                end;
                            Database::"Purch. Inv. Header":
                                begin
                                    PurchInvHeader.ChangeCompany(TargetCompany);
                                    if PurchInvHeader.Get(DocAttachment."No.") then begin
                                        HasDocDate := PurchInvHeader."Document Date" <> 0D;
                                        HasOrderDate := PurchInvHeader."Order Date" <> 0D;
                                        HasHeaderCreated := PurchInvHeader.SystemCreatedAt <> 0DT;
                                    end;
                                end;
                            Database::"Purch. Cr. Memo Hdr.":
                                begin
                                    PurchCrMemoHdr.ChangeCompany(TargetCompany);
                                    if PurchCrMemoHdr.Get(DocAttachment."No.") then begin
                                        HasDocDate := PurchCrMemoHdr."Document Date" <> 0D;
                                        HasHeaderCreated := PurchCrMemoHdr.SystemCreatedAt <> 0DT;
                                    end;
                                end;
                        end;

                        GroupKey := '1173|' + Format(DocAttachment."Table ID") + '|' + Format(DocAttachment."Document Type") + '|' +
                                    Format(HasDocDate) + '|' + Format(HasOrderDate) + '|' + Format(HasAttachCreated) + '|' + Format(HasHeaderCreated);

                        if not CountByGroup.ContainsKey(GroupKey) then begin
                            GroupKeys.Add(GroupKey);
                            CountByGroup.Add(GroupKey, 0);
                            BytesByGroup.Add(GroupKey, 0);
                            TableIdByGroup.Add(GroupKey, DocAttachment."Table ID");
                            DocTypeByGroup.Add(GroupKey, Format(DocAttachment."Document Type"));
                            HasDocDateByGroup.Add(GroupKey, HasDocDate);
                            HasOrderDateByGroup.Add(GroupKey, HasOrderDate);
                            HasAttachCreatedByGroup.Add(GroupKey, HasAttachCreated);
                            HasHeaderCreatedByGroup.Add(GroupKey, HasHeaderCreated);
                        end;
                        CountByGroup.Set(GroupKey, CountByGroup.Get(GroupKey) + 1);
                        BytesByGroup.Set(GroupKey, BytesByGroup.Get(GroupKey) + FileSize);
                        TotalSkipped += 1;
                        TotalBytes += FileSize;
                    end;
            until DocAttachment.Next() = 0;

        // 2. Scan Table 133 (Incoming Document Attachment)
        IncDocAttachment.ChangeCompany(TargetCompany);
        if IncDocAttachment.FindSet(false) then
            repeat
                if not IsIncomingDocEligible(IncDocAttachment, TargetCompany, ArchiveSetup."Cut-Off Date Rule", CutOffDate, EvalDateField, EvalDateValue) then
                    if (CutOffDate <> 0D) and (EvalDateValue = 0D) then begin
                        IncDocAttachment.CalcFields(Content);
                        FileSize := IncDocAttachment.Content.Length();

                        HasDocDate := false;
                        HasOrderDate := false;
                        HasAttachCreated := IncDocAttachment.SystemCreatedAt <> 0DT;
                        HasHeaderCreated := false;

                        IncomingDocument.ChangeCompany(TargetCompany);
                        if IncomingDocument.Get(IncDocAttachment."Incoming Document Entry No.") then begin
                            HasDocDate := IncomingDocument."Document Date" <> 0D;
                            HasHeaderCreated := IncomingDocument.SystemCreatedAt <> 0DT;
                        end;

                        GroupKey := '133|130|IncomingDoc|' +
                                    Format(HasDocDate) + '|' + Format(HasOrderDate) + '|' + Format(HasAttachCreated) + '|' + Format(HasHeaderCreated);

                        if not CountByGroup.ContainsKey(GroupKey) then begin
                            GroupKeys.Add(GroupKey);
                            CountByGroup.Add(GroupKey, 0);
                            BytesByGroup.Add(GroupKey, 0);
                            TableIdByGroup.Add(GroupKey, Database::"Incoming Document");
                            DocTypeByGroup.Add(GroupKey, 'Incoming Document');
                            HasDocDateByGroup.Add(GroupKey, HasDocDate);
                            HasOrderDateByGroup.Add(GroupKey, HasOrderDate);
                            HasAttachCreatedByGroup.Add(GroupKey, HasAttachCreated);
                            HasHeaderCreatedByGroup.Add(GroupKey, HasHeaderCreated);
                        end;
                        CountByGroup.Set(GroupKey, CountByGroup.Get(GroupKey) + 1);
                        BytesByGroup.Set(GroupKey, BytesByGroup.Get(GroupKey) + FileSize);
                        TotalSkipped += 1;
                        TotalBytes += FileSize;
                    end;
            until IncDocAttachment.Next() = 0;

        // 3. Render CSV Output
        TempBlob.CreateOutStream(CsvOutStream, TextEncoding::UTF8);
        CsvOutStream.WriteText(CsvDateMatrixHeaderLbl + CrLf);

        foreach GroupKey in GroupKeys do begin
            TargetTableId := TableIdByGroup.Get(GroupKey);
            TableNameText := 'Unknown Table';
            if AllObjWithCaption.Get(AllObjWithCaption."Object Type"::Table, TargetTableId) then
                TableNameText := AllObjWithCaption."Object Name";

            DecMB := Round(BytesByGroup.Get(GroupKey) / 1048576, 0.01);

            if GroupKey.StartsWith('1173|') then
                CsvOutStream.WriteText(
                    StrSubstNo(CsvDateMatrixRowLbl,
                        TargetCompany,
                        1173,
                        TargetTableId,
                        TableNameText,
                        DocTypeByGroup.Get(GroupKey),
                        HasDocDateByGroup.Get(GroupKey),
                        HasOrderDateByGroup.Get(GroupKey),
                        HasAttachCreatedByGroup.Get(GroupKey),
                        HasHeaderCreatedByGroup.Get(GroupKey),
                        CountByGroup.Get(GroupKey),
                        BytesByGroup.Get(GroupKey),
                        DecMB) + CrLf)
            else
                CsvOutStream.WriteText(
                    StrSubstNo(CsvDateMatrixRowLbl,
                        TargetCompany,
                        133,
                        TargetTableId,
                        TableNameText,
                        DocTypeByGroup.Get(GroupKey),
                        HasDocDateByGroup.Get(GroupKey),
                        HasOrderDateByGroup.Get(GroupKey),
                        HasAttachCreatedByGroup.Get(GroupKey),
                        HasHeaderCreatedByGroup.Get(GroupKey),
                        CountByGroup.Get(GroupKey),
                        BytesByGroup.Get(GroupKey),
                        DecMB) + CrLf);
        end;

        TotalDecMB := Round(TotalBytes / 1048576, 0.01);
        CsvOutStream.WriteText(
            StrSubstNo(CsvDateMatrixTotalLbl, TargetCompany, TotalSkipped, TotalBytes, TotalDecMB) + CrLf);

        TempBlob.CreateInStream(CsvInStream, TextEncoding::UTF8);
        FileName := StrSubstNo(DateFieldBreakdownCsvFileNameLbl, DelChr(TargetCompany, '=', ' /\&*'), Format(Today(), 0, '<Year4><Month,2><Day,2>'));
        DownloadFromStream(CsvInStream, 'Export Date Field Availability Breakdown', '', 'CSV Files (*.csv)|*.csv', FileName);
    end;

    var
        SummaryMsg: Label 'Preview / Dry-Run hoàn tất:\- Tổng số tệp thỏa điều kiện: %1\- Tổng dung lượng dự kiến giải phóng: %2\- Ngày Cut-off: %3\- Số tệp bỏ qua do ngày trống (No-Fallback): %4\(Lưu ý: Chế độ Dry-Run chỉ quét thống kê, không upload và không xóa bất kỳ dữ liệu nào trên BC).', Comment = '%1 = File count, %2 = Formatted size, %3 = Cut-off date, %4 = Skipped count';
        PreviewLogMsg: Label 'Preview scan completed: %1 eligible files, %2 bytes evaluated. Skipped empty date: %3.', Comment = '%1 = File count, %2 = Bytes, %3 = Skipped count';
        VerificationProofTxt: Label 'Cut-Off Date: %1, Rule: %2', Comment = '%1 = Date, %2 = Rule';
        SizeKBLbl: Label '%1 KB', Comment = '%1 = Kilobytes';
        SizeMBLbl: Label '%1 MB', Comment = '%1 = Megabytes';
        CsvRow1173Lbl: Label '"%1",1173,%2,"%3","%4","%5",%6', Locked = true;
        CsvRow133Lbl: Label '"%1",133,%2,"%3","%4","%5",%6', Locked = true;
        CsvRowTotalLbl: Label '"%1",TOTAL,0,"ALL SKIPPED FILES","ALL","Total Skipped (Blank Date / Strict No-Fallback)",%2', Locked = true;
        SkippedCsvFileNameLbl: Label 'SkippedFilesBreakdown_%1_%2.csv', Locked = true;
        DateFieldBreakdownCsvFileNameLbl: Label 'SkippedDateFieldBreakdown_%1_%2.csv', Locked = true;
        CsvDateMatrixHeaderLbl: Label 'Company,Attachment Table ID,Target Source Table ID,Target Source Table Name,Document Type,Has Document Date,Has Order/Quote Date,Has Attachment SystemCreatedAt,Has Header SystemCreatedAt,Skipped File Count,Total Size (Bytes),Total Size (MB)', Locked = true;
        CsvDateMatrixRowLbl: Label '"%1",%2,%3,"%4","%5",%6,%7,%8,%9,%10,%11,%12', Locked = true;
        CsvDateMatrixTotalLbl: Label '"%1",TOTAL,0,"ALL SKIPPED FILES","ALL",-,-,-,-,%2,%3,%4', Locked = true;
}
