namespace APSS.FileArchiving;

page 50140 "Azure Blob Archive Setup"
{
    PageType = Card;
    ApplicationArea = Basic, Suite;
    UsageCategory = Administration;
    SourceTable = "Archive Setup";
    Caption = 'Azure Blob Archive Setup';
    AdditionalSearchTerms = 'azure, blob, archive, setup, storage';
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'Azure Storage Account Connection';

                field("Storage Account Name"; Rec."Storage Account Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Azure Storage Account name.';
                }
                field("Container Name"; Rec."Container Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Azure Blob Container name for archiving.';
                }
                field(SasToken; SasTokenVar)
                {
                    ApplicationArea = All;
                    Caption = 'SAS Token';
                    ExtendedDatatype = Masked;
                    ToolTip = 'Specifies the Shared Access Signature (SAS) Token for Azure Blob authentication. Stored securely in IsolatedStorage.';

                    trigger OnValidate()
                    var
                        BlobClient: Codeunit "Azure Blob Storage Client";
                    begin
                        if SasTokenVar = '' then
                            BlobClient.SetSasToken('')
                        else
                            if SasTokenVar <> '********' then
                                BlobClient.SetSasToken(SasTokenVar);
                        CurrPage.Update(false);
                    end;
                }
                field("Is Configured"; Rec."Is Configured")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Indicates if the connection settings have been validated successfully.';
                }
            }

            group(StoragePolicy)
            {
                Caption = 'Storage & Archiving Policy';

                field("Base Folder Path"; Rec."Base Folder Path")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the base virtual folder path inside the container.';
                }
                field("Default Access Tier"; Rec."Default Access Tier")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the default Azure Blob tier upon upload (Cool, Hot, Cold, Archive).';
                }
                field("Cut-Off Date Rule"; Rec."Cut-Off Date Rule")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the admin evaluation date rule for eligibility (Posting Date or Document Date).';
                }
                field("Batch Size"; Rec."Batch Size")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of files to process per background job run (1-500).';
                }
                field("Chunk Size (MB)"; Rec."Chunk Size (MB)")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the block chunk size in megabytes for upload (1-100 MB).';
                }
            }

            group(ApprovalAndSafety)
            {
                Caption = 'Approval & Safety Controls (Purge Hard-Locked)';

                field("Require Secondary Approval"; Rec."Require Secondary Approval")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies if secondary approval is strictly required prior to any binary purge.';
                }
                field("Approver Role ID"; Rec."Approver Role ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the user security role ID authorized to grant secondary approval.';
                }
                field("Approval Expiry (Days)"; Rec."Approval Expiry (Days)")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of days after which an approved batch expires and requires re-verification.';
                }
                field("WORM Policy Enabled"; Rec."WORM Policy Enabled")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies if WORM / Immutability policy is enabled on the container. Must remain configurable and unlocked during PoC.';
                }
                field("WORM Policy Locked"; Rec."WORM Policy Locked")
                {
                    ApplicationArea = All;
                    Editable = false;
                    ToolTip = 'Specifies if the WORM policy has been permanently locked on Azure Storage. Irreversible once locked.';
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(TestConnection)
            {
                ApplicationArea = All;
                Caption = 'Test Connection';
                Image = Link;
                ToolTip = 'Validates Azure Blob Storage authentication and verifies that the container exists and is accessible.';

                trigger OnAction()
                var
                    BlobClient: Codeunit "Azure Blob Storage Client";
                begin
                    BlobClient.TestConnection(Rec);
                end;
            }
            action(RunDryRun)
            {
                ApplicationArea = All;
                Caption = 'Run Preview / Dry Run';
                Image = Start;
                ToolTip = 'Scans attachments matching the Cut-Off Date and shows the eligible file count and potential capacity release without uploading or purging anything.';

                trigger OnAction()
                var
                    DryRunScanner: Codeunit "Archive Dry-Run Scanner";
                begin
                    DryRunScanner.RunDryRun(Rec, WorkDate(), true);
                end;
            }
        }
        area(Navigation)
        {
            action(OpenQueue)
            {
                ApplicationArea = All;
                Caption = 'Archive Queue';
                Image = Archive;
                RunObject = page "Azure Blob Archive Queue";
                ToolTip = 'Opens the centralized archive queue to inspect files, statuses, and links.';
            }
            action(OpenAuditLog)
            {
                ApplicationArea = All;
                Caption = 'Audit Log';
                Image = Log;
                RunObject = page "Azure Blob Archive Audit Logs";
                ToolTip = 'Opens the immutable audit log for all archiving actions.';
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(TestConnection_Promoted; TestConnection)
                {
                }
                actionref(RunDryRun_Promoted; RunDryRun)
                {
                }
            }
            group(Category_Archive)
            {
                Caption = 'Archive';

                actionref(OpenQueue_Promoted; OpenQueue)
                {
                }
                actionref(OpenAuditLog_Promoted; OpenAuditLog)
                {
                }
            }
        }
    }

    trigger OnOpenPage()
    var
        BlobClient: Codeunit "Azure Blob Storage Client";
    begin
        Rec.Reset();
        if not Rec.Get() then begin
            Rec.Init();
            Rec."Primary Key" := '';
            Rec."Default Access Tier" := Rec."Default Access Tier"::Cool;
            Rec."Cut-Off Date Rule" := Rec."Cut-Off Date Rule"::"Posting Date";
            Rec."Batch Size" := 50;
            Rec."Chunk Size (MB)" := 4;
            Rec."Require Secondary Approval" := true;
            Rec."Approval Expiry (Days)" := 7;
            Rec.Insert(true);
        end;

        if BlobClient.HasSasToken() then
            SasTokenVar := '********'
        else
            SasTokenVar := '';
    end;

    var
        SasTokenVar: Text;
}
