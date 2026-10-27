namespace APSS.FileArchiving;

using Microsoft.EServices.EDocument;

pageextension 50141 "Inc Doc Attachments Ext" extends "Incoming Document Attachments"
{
    layout
    {
        addafter("File Extension")
        {
            field("Archived to SharePoint"; IsArchivedToSharePoint)
            {
                ApplicationArea = All;
                Caption = 'Archived to SharePoint';
                Editable = false;
                ToolTip = 'Specifies whether this incoming attachment has been successfully archived to SharePoint Online.';
            }
        }
    }

    actions
    {
        addafter(Export)
        {
            action(OpenFromSharePoint)
            {
                ApplicationArea = All;
                Caption = 'Open from SharePoint';
                Image = Web;
                Scope = Repeater;
                ToolTip = 'Opens the archived incoming document attachment directly in SharePoint Online.';
                Enabled = IsArchivedToSharePoint;

                trigger OnAction()
                var
                    IncDocAttachment: Record "Incoming Document Attachment";
                    LinkMapping: Record "Archive Link Mapping";
                begin
                    if not IncDocAttachment.Get(Rec."Incoming Document Entry No.", Rec."Line No.") then begin
                        Message(NotArchivedMsg);
                        exit;
                    end;

                    if not LinkMapping.Get(CopyStr(CompanyName(), 1, 30), IncDocAttachment.SystemId) then begin
                        Message(NotArchivedMsg);
                        exit;
                    end;

                    if LinkMapping."SharePoint Web URL" <> '' then
                        Hyperlink(LinkMapping."SharePoint Web URL")
                    else
                        Message(NoSharePointUrlMsg);
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        IncDocAttachment: Record "Incoming Document Attachment";
        LinkMapping: Record "Archive Link Mapping";
    begin
        IsArchivedToSharePoint := false;
        if IncDocAttachment.Get(Rec."Incoming Document Entry No.", Rec."Line No.") then
            IsArchivedToSharePoint := LinkMapping.Get(CopyStr(CompanyName(), 1, 30), IncDocAttachment.SystemId);
    end;

    var
        IsArchivedToSharePoint: Boolean;
        NotArchivedMsg: Label 'This incoming document attachment has not been archived to SharePoint yet.';
        NoSharePointUrlMsg: Label 'This attachment is recorded as archived, but no SharePoint URL was found.';
}
