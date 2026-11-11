namespace APSS.FileArchiving;

using System.Environment;

codeunit 50142 "Azure Blob Purge Job Queue"
{
    Caption = 'Azure Blob Purge Job Queue';

    var
        BatchSummaryMsg: Label 'Purge Job Queue Batch completed: %1 of %2 files purged (%3 released). Remaining: %4 files (%5).', Comment = '%1 = Purged count, %2 = Processed count, %3 = Purged bytes formatted, %4 = Remaining count, %5 = Remaining bytes formatted';
        AuditBatchSummaryMsg: Label 'Purge Job Queue Batch: %1 of %2 files purged (%3 released). Before: %4 files (%5). Remaining: %6 files (%7).', Comment = '%1 = Purged count, %2 = Processed count, %3 = Purged bytes formatted, %4 = Initial count, %5 = Initial bytes formatted, %6 = Remaining count, %7 = Remaining bytes formatted';
        AuditProofTxt: Label 'Checkpoint: BatchLimit=%1, Processed=%2, Purged=%3, ReleasedBytes=%4', Comment = '%1 = Limit, %2 = Processed, %3 = Purged, %4 = Bytes';
        SizeKBLbl: Label '%1 KB', Locked = true;
        SizeMBLbl: Label '%1 MB', Locked = true;
        SizeGBLbl: Label '%1 GB', Locked = true;
        MissingMappingErr: Label 'Purge aborted by Job Queue: Missing Blob Link Mapping or empty Blob URL.';

    trigger OnRun()
    var
        ArchiveSetup: Record "Archive Setup";
        BatchLimit: Integer;
    begin
        BatchLimit := 500;
        if ArchiveSetup.Get() then
            if ArchiveSetup."Batch Size" > 0 then
                BatchLimit := ArchiveSetup."Batch Size";

        RunPurgeBatch(BatchLimit);
    end;

    procedure RunPurgeBatch(BatchLimit: Integer): Integer
    var
        ArchiveSetup: Record "Archive Setup";
        ArchiveQueueEntry: Record "Archive Queue Entry";
        LinkMapping: Record "Archive Link Mapping";
        AuditLog: Record "Archive Audit Log";
        BlobClient: Codeunit "Azure Blob Storage Client";
        EntryList: List of [BigInteger];
        EntryNo: BigInteger;
        InitialCount: Integer;
        InitialBytes: BigInteger;
        RemainingCount: Integer;
        RemainingBytes: BigInteger;
        ProcessedCount: Integer;
        PurgedCount: Integer;
        PurgedBytes: BigInteger;
    begin
        // Environment Guard: Strictly blocked on Production APSS
        BlobClient.ValidatePurgeAllowed();

        if BatchLimit <= 0 then
            BatchLimit := 500;

        // Metric Before: Calculate initial pending eligible files & size
        CalculateEligibleMetrics(InitialCount, InitialBytes);

        if InitialCount = 0 then begin
            if GuiAllowed() then
                Message('No eligible verified files pending purge.');
            exit(0);
        end;

        // Query eligible queue entries
        ArchiveQueueEntry.SetCurrentKey("Archive Status", "Entry No.");
        ArchiveQueueEntry.SetRange("Archive Status", ArchiveQueueEntry."Archive Status"::Verified);
        ArchiveQueueEntry.SetFilter("Purge Status", '%1|%2',
            Enum::"Purge Process Status"::Approved,
            Enum::"Purge Process Status"::PendingApproval);
        ArchiveQueueEntry.SetFilter("Blob Full URL", '<>%1', '');
        ArchiveQueueEntry.SetFilter("Retry Count", '<%1', 3);

        if ArchiveQueueEntry.FindSet(false) then
            repeat
                EntryList.Add(ArchiveQueueEntry."Entry No.");
            until (ArchiveQueueEntry.Next() = 0) or (EntryList.Count() >= BatchLimit);

        // Process batch with checkpoints and per-file commits (supports Pause / Resume)
        foreach EntryNo in EntryList do
            if ArchiveQueueEntry.Get(EntryNo) then begin
                ProcessedCount += 1;

                // Validate blob mapping and remote URL existence prior to purge
                if not LinkMapping.Get(ArchiveQueueEntry."Company Name", ArchiveQueueEntry."Attachment SystemId") or
                   (LinkMapping."Blob Full URL" = '')
                then begin
                    ArchiveQueueEntry."Retry Count" += 1;
                    ArchiveQueueEntry."Last Error Message" := CopyStr(MissingMappingErr, 1, MaxStrLen(ArchiveQueueEntry."Last Error Message"));
                    ArchiveQueueEntry.Modify(false);
                end else
                    if BlobClient.PurgeQueueEntry(ArchiveQueueEntry) then begin
                        PurgedCount += 1;
                        PurgedBytes += ArchiveQueueEntry."Original File Size (Bytes)";
                    end;

                // Checkpoint: Commit transaction after each file
                Commit();
            end;

        // Metric After: Calculate remaining pending files & size
        CalculateEligibleMetrics(RemainingCount, RemainingBytes);

        // Log batch summary into Audit Trail
        AuditLog.Init();
        AuditLog."Log Entry No." := 0;
        AuditLog."Queue Entry No." := 0;
        AuditLog."Company Name" := CopyStr(CompanyName(), 1, MaxStrLen(AuditLog."Company Name"));
        AuditLog."Event DateTime" := CurrentDateTime();
        AuditLog."User ID" := CopyStr(UserId(), 1, MaxStrLen(AuditLog."User ID"));
        AuditLog."Action Type" := Enum::"Archive Audit Action"::PurgeCompleted;
        AuditLog."Message" := CopyStr(StrSubstNo(AuditBatchSummaryMsg,
            PurgedCount, ProcessedCount, FormatBytes(PurgedBytes),
            InitialCount, FormatBytes(InitialBytes),
            RemainingCount, FormatBytes(RemainingBytes)), 1, MaxStrLen(AuditLog."Message"));
        AuditLog."Verification Proof" := CopyStr(StrSubstNo(AuditProofTxt,
            BatchLimit, ProcessedCount, PurgedCount, PurgedBytes), 1, MaxStrLen(AuditLog."Verification Proof"));
        AuditLog.Insert(true);
        Commit();

        if GuiAllowed() then
            Message(BatchSummaryMsg, PurgedCount, ProcessedCount, FormatBytes(PurgedBytes), RemainingCount, FormatBytes(RemainingBytes));

        exit(PurgedCount);
    end;

    local procedure CalculateEligibleMetrics(var OutCount: Integer; var OutBytes: BigInteger)
    var
        ArchiveQueueEntry: Record "Archive Queue Entry";
    begin
        OutCount := 0;
        OutBytes := 0;

        ArchiveQueueEntry.SetCurrentKey("Archive Status", "Entry No.");
        ArchiveQueueEntry.SetRange("Archive Status", ArchiveQueueEntry."Archive Status"::Verified);
        ArchiveQueueEntry.SetFilter("Purge Status", '%1|%2',
            Enum::"Purge Process Status"::Approved,
            Enum::"Purge Process Status"::PendingApproval);
        ArchiveQueueEntry.SetFilter("Blob Full URL", '<>%1', '');
        ArchiveQueueEntry.SetFilter("Retry Count", '<%1', 3);

        if ArchiveQueueEntry.FindSet(false) then
            repeat
                OutCount += 1;
                OutBytes += ArchiveQueueEntry."Original File Size (Bytes)";
            until ArchiveQueueEntry.Next() = 0;
    end;

    local procedure FormatBytes(Bytes: BigInteger): Text
    var
        MB: Decimal;
        GB: Decimal;
    begin
        if Bytes >= 1073741824 then begin
            GB := Bytes / 1073741824;
            exit(StrSubstNo(SizeGBLbl, Round(GB, 0.01)));
        end;
        MB := Bytes / 1048576;
        if MB < 1 then
            exit(StrSubstNo(SizeKBLbl, Bytes div 1024));
        exit(StrSubstNo(SizeMBLbl, Round(MB, 0.01)));
    end;
}
