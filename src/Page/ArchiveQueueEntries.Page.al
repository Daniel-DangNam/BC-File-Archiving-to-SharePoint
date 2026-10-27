namespace APSS.FileArchiving;

page 50141 "Archive Queue Entries"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = Lists;
    SourceTable = "Archive Queue Entry";
    SourceTableView = sorting("Entry No.") order(descending);
    Caption = 'SharePoint Archive Queue Entries';
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
                field("SharePoint Web URL"; Rec."SharePoint Web URL")
                {
                    ApplicationArea = All;
                    ExtendedDatatype = URL;
                    ToolTip = 'Specifies the web URL to open the archived file on SharePoint Online.';
                }
                field("SharePoint Item ID"; Rec."SharePoint Item ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the SharePoint Drive Item ID assigned by Graph API.';
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
                    ToolTip = 'Specifies the date and time when the upload to SharePoint completed.';
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
            action(UploadToSharePoint)
            {
                ApplicationArea = All;
                Caption = 'Upload Selected';
                Image = Cloud;
                ToolTip = 'Uploads and verifies the currently selected queue entry to SharePoint Online.';

                trigger OnAction()
                var
                    GraphClient: Codeunit "SP Archive Graph Client";
                begin
                    GraphClient.ProcessQueueEntry(Rec);
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
                    GraphClient: Codeunit "SP Archive Graph Client";
                begin
                    ArchiveSetup.Get();
                    GraphClient.ProcessPendingQueueEntries(ArchiveSetup."Batch Size");
                    CurrPage.Update(false);
                end;
            }
            action(OpenInSharePoint)
            {
                ApplicationArea = All;
                Caption = 'Open in SharePoint';
                Image = Web;
                ToolTip = 'Opens the archived document directly in SharePoint Online.';
                Enabled = Rec."SharePoint Web URL" <> '';

                trigger OnAction()
                begin
                    if Rec."SharePoint Web URL" <> '' then
                        Hyperlink(Rec."SharePoint Web URL");
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
                    AuditLogsPage: Page "Archive Audit Logs";
                begin
                    AuditLog.SetRange("Queue Entry No.", Rec."Entry No.");
                    AuditLogsPage.SetTableView(AuditLog);
                    AuditLogsPage.Run();
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
                RunObject = page "Archive Setup";
                ToolTip = 'Opens the SharePoint archive setup configuration page.';
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
                actionref(UploadToSharePoint_Promoted; UploadToSharePoint)
                {
                }
                actionref(ProcessBatch_Promoted; ProcessBatch)
                {
                }
                actionref(OpenInSharePoint_Promoted; OpenInSharePoint)
                {
                }
                actionref(ViewAuditLog_Promoted; ViewAuditLog)
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
