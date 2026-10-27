namespace APSS.FileArchiving;

page 50142 "Archive Audit Logs"
{
    PageType = List;
    ApplicationArea = All;
    UsageCategory = History;
    SourceTable = "Archive Audit Log";
    SourceTableView = sorting("Log Entry No.") order(descending);
    Caption = 'SharePoint Archive Audit Logs';
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
                field("Log Entry No."; Rec."Log Entry No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the unique sequential log entry number.';
                }
                field("Queue Entry No."; Rec."Queue Entry No.")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the associated archive queue entry number.';
                }
                field("Company Name"; Rec."Company Name")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the Business Central company name where the event occurred.';
                }
                field("Event DateTime"; Rec."Event DateTime")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the exact timestamp when the audit event was logged.';
                }
                field("User ID"; Rec."User ID")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the user or system background job ID that executed the action.';
                }
                field("Action Type"; Rec."Action Type")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the archiving or verification action type.';
                }
                field("Old Status"; Rec."Old Status")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the status prior to the transition.';
                }
                field("New Status"; Rec."New Status")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the status after the transition.';
                }
                field("Message"; Rec."Message")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies detailed information or error description.';
                }
                field("Verification Proof"; Rec."Verification Proof")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the technical verification proof (Drive Item ID, size, hash, ETag).';
                }
            }
        }
    }
}
