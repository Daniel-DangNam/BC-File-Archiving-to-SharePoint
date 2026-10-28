namespace APSS.FileArchiving;

page 50140 "SharePoint Archive Setup"
{
    PageType = Card;
    ApplicationArea = Basic, Suite;
    UsageCategory = Administration;
    SourceTable = "Archive Setup";
    Caption = 'SharePoint Archive Setup';
    AdditionalSearchTerms = 'sharepoint, archive, setup, storage';
    InsertAllowed = false;
    DeleteAllowed = false;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'Microsoft Entra ID Connection';

                field("Tenant ID"; Rec."Tenant ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Microsoft Entra Directory (Tenant) ID.';
                }
                field("Client ID"; Rec."Client ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the App Registration Client (Application) ID.';
                }
                field(ClientSecret; ClientSecretVar)
                {
                    ApplicationArea = All;
                    Caption = 'Client Secret';
                    ExtendedDatatype = Masked;
                    ToolTip = 'Specifies the Client Secret for Graph API authentication. The value is stored securely in IsolatedStorage.';

                    trigger OnValidate()
                    begin
                        SaveClientSecret();
                    end;
                }
                field("Is Configured"; Rec."Is Configured")
                {
                    ApplicationArea = All;
                    ToolTip = 'Indicates if the connection settings have been validated.';
                }
            }

            group(SharePoint)
            {
                Caption = 'SharePoint Storage Target';

                field("SharePoint Site ID"; Rec."SharePoint Site ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Microsoft Graph SharePoint Site ID.';
                }
                field("SharePoint Drive ID"; Rec."SharePoint Drive ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the SharePoint Document Library Drive ID.';
                }
                field("Base Folder Path"; Rec."Base Folder Path")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the base folder path inside the document library.';
                }
            }

            group(ArchivingPolicy)
            {
                Caption = 'Archiving & Upload Policy';

                field("Cut-Off Date Rule"; Rec."Cut-Off Date Rule")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the date field used to evaluate eligibility for archiving (Posting Date, Document Date, or Attached Date).';
                }
                field("Batch Size"; Rec."Batch Size")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the number of files to process per background job run (1-500).';
                }
                field("Chunk Size (MB)"; Rec."Chunk Size (MB)")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the chunk size in megabytes for resumable upload sessions (4-60 MB).';
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
                ToolTip = 'Validates the Microsoft Entra ID authentication and verifies that the specified SharePoint Drive exists and is accessible.';

                trigger OnAction()
                var
                    GraphClient: Codeunit "SP Archive Graph Client";
                begin
                    GraphClient.TestConnection(Rec);
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
                RunObject = page "SharePoint Archive Queue";
                ToolTip = 'Opens the centralized archive queue to inspect files, statuses, and links.';
            }
            action(OpenAuditLog)
            {
                ApplicationArea = All;
                Caption = 'Audit Log';
                Image = Log;
                RunObject = page "SharePoint Archive Audit Logs";
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
    begin
        Rec.Reset();
        if not Rec.Get() then begin
            Rec.Init();
            Rec."Primary Key" := '';
            Rec."Batch Size" := 50;
            Rec."Chunk Size (MB)" := 4;
            Rec."Require Secondary Approval" := true;
            Rec."Approval Expiry (Days)" := 7;
            Rec.Insert(true);
        end;

        LoadClientSecret();
    end;

    var
        ClientSecretVar: Text;
        SecretKeyLbl: Label 'SP_ARCHIVE_CLIENT_SECRET', Locked = true;

    local procedure LoadClientSecret()
    begin
        if IsolatedStorage.Contains(SecretKeyLbl, DataScope::Company) then
            ClientSecretVar := '********'
        else
            ClientSecretVar := '';
    end;

    local procedure SaveClientSecret()
    begin
        if ClientSecretVar = '' then begin
            if IsolatedStorage.Contains(SecretKeyLbl, DataScope::Company) then
                IsolatedStorage.Delete(SecretKeyLbl, DataScope::Company);
        end else
            if ClientSecretVar <> '********' then
                IsolatedStorage.Set(SecretKeyLbl, ClientSecretVar, DataScope::Company);
    end;
}
