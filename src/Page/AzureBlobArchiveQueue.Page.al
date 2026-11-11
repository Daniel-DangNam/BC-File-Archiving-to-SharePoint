namespace APSS.FileArchiving;

page 50141 "Azure Blob Archive Queue"
{
    PageType = List;
    ApplicationArea = Basic, Suite;
    UsageCategory = Lists;
    SourceTable = "Archive Queue Entry";
    SourceTableView = sorting("Entry No.") order(descending);
    Caption = 'Azure Blob Archive Queue Entries';
    AdditionalSearchTerms = 'azure, blob, archive, queue, storage';
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            repeater(Group)
            {
                field("Entry No."; Rec."Entry No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the unique sequential entry number.';
                }
                field("Company Name"; Rec."Company Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Business Central company context of the source document.';
                }
                field("Source Table ID"; Rec."Source Table ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the source table ID (e.g. 1173 for Document Attachment, 133 for Incoming Document Attachment).';
                }
                field("Source Document Type"; Rec."Source Document Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the source document type (e.g. Order, Invoice, Quote).';
                }
                field("Source Document No."; Rec."Source Document No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the business document number in Business Central.';
                }
                field("File Name"; Rec."File Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the original name of the attachment file.';
                }
                field("File Extension"; Rec."File Extension")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the extension of the file.';
                }
                field("Original File Size (Bytes)"; Rec."Original File Size (Bytes)")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the exact size of the binary file in bytes.';
                }
                field("Evaluated Date Field"; Rec."Evaluated Date Field")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the date field evaluated for cut-off eligibility.';
                }
                field("Evaluated Date Value"; Rec."Evaluated Date Value")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the evaluated date value of the source document.';
                }
                field("Archive Status"; Rec."Archive Status")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the current upload & verification lifecycle status.';
                }
                field("Purge Status"; Rec."Purge Status")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the binary purge lifecycle status (Hard-Locked).';
                }
                field("Is Shared Media"; Rec."Is Shared Media")
                {
                    ApplicationArea = All;
                    ToolTip = 'Indicates if this binary media is shared across multiple business records.';
                }
                field("Is Dry Run"; Rec."Is Dry Run")
                {
                    ApplicationArea = All;
                    ToolTip = 'Indicates if this record was generated as part of a preview / dry run execution.';
                }
                field("Blob Relative Path"; Rec."Blob Relative Path")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the virtual relative path in the Azure Blob Container.';
                }
                field("Blob Full URL"; Rec."Blob Full URL")
                {
                    ApplicationArea = All;
                    ExtendedDatatype = URL;
                    ToolTip = 'Specifies the permanent URL of the archived file in Azure Blob Storage.';
                }
                field("Blob ETag"; Rec."Blob ETag")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the ETag version returned by Azure Blob Storage.';
                }
                field("Blob Content MD5"; Rec."Blob Content MD5")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Content-MD5 hash of the blob.';
                }
                field("Retry Count"; Rec."Retry Count")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of retry attempts executed for this file.';
                }
                field("Last Error Message"; Rec."Last Error Message")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the last error message recorded during processing.';
                }
                field("Queued DateTime"; Rec."Queued DateTime")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the date and time when the file was queued.';
                }
                field("Uploaded DateTime"; Rec."Uploaded DateTime")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the date and time when the upload to Azure Blob completed.';
                }
                field("Verified DateTime"; Rec."Verified DateTime")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the date and time when byte-exact verification succeeded.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(RunDryRun)
            {
                ApplicationArea = All;
                Caption = 'Run Preview / Dry Run';
                Image = Start;
                ToolTip = 'Scans attachments matching the Cut-Off Date and populates the queue in Draft mode.';

                trigger OnAction()
                var
                    ArchiveSetup: Record "Archive Setup";
                    DryRunScanner: Codeunit "Archive Dry-Run Scanner";
                begin
                    ArchiveSetup.Get();
                    DryRunScanner.RunDryRun(ArchiveSetup, WorkDate(), true);
                    CurrPage.Update(false);
                end;
            }
            action(ExportSkippedBreakdown)
            {
                ApplicationArea = All;
                Caption = 'Export Skipped Files Breakdown (CSV)';
                Image = ExportToExcel;
                ToolTip = 'Exports a detailed CSV breakdown of all skipped attachments grouped by Source Table ID, Table Name, Document Type, and Skip Reason.';

                trigger OnAction()
                var
                    ArchiveSetup: Record "Archive Setup";
                    DryRunScanner: Codeunit "Archive Dry-Run Scanner";
                begin
                    ArchiveSetup.Get();
                    DryRunScanner.ExportSkippedBreakdownCsv(ArchiveSetup, WorkDate());
                end;
            }
            action(UploadToBlob)
            {
                ApplicationArea = All;
                Caption = 'Upload Selected';
                Image = Cloud;
                ToolTip = 'Uploads and verifies the currently selected queue entry to Azure Blob Storage.';

                trigger OnAction()
                var
                    BlobClient: Codeunit "Azure Blob Storage Client";
                begin
                    BlobClient.ProcessQueueEntry(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(ProcessBatch)
            {
                ApplicationArea = All;
                Caption = 'Process Batch';
                Image = Process;
                ToolTip = 'Processes a batch of pending and failed queue entries according to configured batch size.';

                trigger OnAction()
                var
                    ArchiveSetup: Record "Archive Setup";
                    BlobClient: Codeunit "Azure Blob Storage Client";
                begin
                    ArchiveSetup.Get();
                    BlobClient.ProcessPendingQueueEntries(ArchiveSetup."Batch Size");
                    CurrPage.Update(false);
                end;
            }
            action(OpenInBlob)
            {
                ApplicationArea = All;
                Caption = 'Open in Azure Blob';
                Image = Web;
                ToolTip = 'Opens the archived document via a secure temporary SAS URL.';
                Enabled = Rec."Blob Full URL" <> '';

                trigger OnAction()
                var
                    BlobClient: Codeunit "Azure Blob Storage Client";
                    ViewUrl: Text;
                begin
                    ViewUrl := BlobClient.GenerateTemporaryViewUrl(Rec);
                    if ViewUrl <> '' then
                        Hyperlink(ViewUrl);
                end;
            }
            action(ViewAuditLog)
            {
                ApplicationArea = All;
                Caption = 'Audit Trail';
                Image = Log;
                ToolTip = 'Views the audit log entries related to this queue item.';

                trigger OnAction()
                var
                    AuditLog: Record "Archive Audit Log";
                    AuditLogsPage: Page "Azure Blob Archive Audit Logs";
                begin
                    AuditLog.SetRange("Queue Entry No.", Rec."Entry No.");
                    AuditLogsPage.SetTableView(AuditLog);
                    AuditLogsPage.Run();
                end;
            }
            action(PurgeSelected)
            {
                ApplicationArea = All;
                Caption = 'Purge Selected Binary (Sandbox Only)';
                Image = Delete;
                ToolTip = 'Purges the local binary content in BC for the selected verified file on Sandbox. Remote Azure Blob remains fully accessible.';
                Enabled = (Rec."Archive Status" = Rec."Archive Status"::Verified) and (Rec."Purge Status" <> Rec."Purge Status"::Purged);

                trigger OnAction()
                var
                    BlobClient: Codeunit "Azure Blob Storage Client";
                begin
                    if not Confirm('Are you sure you want to purge local binary data for "%1" on Sandbox?\The file has been verified and will remain accessible via Azure Blob Storage.', false, Rec."File Name") then
                        exit;
                    BlobClient.PurgeQueueEntry(Rec);
                    CurrPage.Update(false);
                end;
            }
            action(PurgeBatch)
            {
                ApplicationArea = All;
                Caption = 'Purge Verified Batch (Sandbox Only)';
                Image = Delete;
                ToolTip = 'Purges local binary content in BC for a batch of verified files on Sandbox to release storage.';

                trigger OnAction()
                var
                    ArchiveSetup: Record "Archive Setup";
                    BlobClient: Codeunit "Azure Blob Storage Client";
                begin
                    ArchiveSetup.Get();
                    if not Confirm('Are you sure you want to purge local binary data for verified files on Sandbox?\All verified files will remain accessible via Azure Blob Storage.', false) then
                        exit;
                    BlobClient.PurgeVerifiedQueueEntries(ArchiveSetup."Batch Size");
                    CurrPage.Update(false);
                end;
            }
        }
        area(Navigation)
        {
            action(OpenSetup)
            {
                ApplicationArea = All;
                Caption = 'Archive Setup';
                Image = Setup;
                RunObject = page "Azure Blob Archive Setup";
                ToolTip = 'Opens the Azure Blob archive setup configuration page.';
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(RunDryRun_Promoted; RunDryRun)
                {
                }
                actionref(ExportSkippedBreakdown_Promoted; ExportSkippedBreakdown)
                {
                }
                actionref(UploadToBlob_Promoted; UploadToBlob)
                {
                }
                actionref(ProcessBatch_Promoted; ProcessBatch)
                {
                }
                actionref(OpenInBlob_Promoted; OpenInBlob)
                {
                }
                actionref(ViewAuditLog_Promoted; ViewAuditLog)
                {
                }
                actionref(PurgeSelected_Promoted; PurgeSelected)
                {
                }
                actionref(PurgeBatch_Promoted; PurgeBatch)
                {
                }
            }
            group(Category_Setup)
            {
                Caption = 'Setup';

                actionref(OpenSetup_Promoted; OpenSetup)
                {
                }
            }
        }
    }
}
