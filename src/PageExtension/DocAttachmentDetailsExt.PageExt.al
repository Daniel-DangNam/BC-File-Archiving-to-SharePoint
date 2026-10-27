namespace APSS.FileArchiving;

using Microsoft.Foundation.Attachment;

pageextension 50140 "Doc Attachment Details Ext" extends "Document Attachment Details"
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
                ToolTip = 'Specifies whether this attachment has been successfully archived to SharePoint Online.';
            }
        }
    }

    actions
    {
        addafter(Preview)
        {
            action(OpenFromSharePoint)
            {
                ApplicationArea = All;
                Caption = 'Open from SharePoint';
                Image = Web;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                ToolTip = 'Opens the archived document directly in SharePoint Online.';
                Scope = Repeater;
                Enabled = IsArchivedToSharePoint;

                trigger OnAction()
                var
                    LinkMapping: Record "Archive Link Mapping";
                begin
                    if LinkMapping.Get(CopyStr(CompanyName(), 1, 30), Rec.SystemId) then begin
                        if LinkMapping."SharePoint Web URL" <> '' then
                            Hyperlink(LinkMapping."SharePoint Web URL")
                        else
                            Message(NoSharePointUrlMsg);
                    end else
                        Message(NotArchivedMsg);
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        LinkMapping: Record "Archive Link Mapping";
    begin
        IsArchivedToSharePoint := LinkMapping.Get(CopyStr(CompanyName(), 1, 30), Rec.SystemId);
    end;

    var
        IsArchivedToSharePoint: Boolean;
        NotArchivedMsg: Label 'This attachment has not been archived to SharePoint yet.';
        NoSharePointUrlMsg: Label 'This attachment is recorded as archived, but no SharePoint URL was found.';
}
