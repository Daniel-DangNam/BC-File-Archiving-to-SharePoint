namespace APSS.FileArchiving;

using Microsoft.Foundation.Attachment;

pageextension 50140 "Doc Attachment Details Ext" extends "Document Attachment Details"
{
    layout
    {
        addafter("File Extension")
        {
            field("Archived to Azure Blob"; IsArchivedToBlob)
            {
                ApplicationArea = All;
                Caption = 'Archived to Azure Blob';
                Editable = false;
                ToolTip = 'Specifies whether this attachment has been successfully archived to Azure Blob Storage.';
            }
        }
    }

    actions
    {
        addafter(Preview)
        {
            action(OpenFromBlob)
            {
                ApplicationArea = All;
                Caption = 'Open from Azure Blob';
                Image = Web;
                ToolTip = 'Opens the archived document directly in Azure Blob Storage via a secure SAS URL.';
                Scope = Repeater;
                Enabled = IsArchivedToBlob;

                trigger OnAction()
                var
                    LinkMapping: Record "Archive Link Mapping";
                    ViewUrl: Text;
                begin
                    if LinkMapping.Get(CopyStr(CompanyName(), 1, 30), Rec.SystemId) then begin
                        ViewUrl := GetViewUrl(LinkMapping);
                        if ViewUrl <> '' then
                            Hyperlink(ViewUrl)
                        else
                            Message(NoBlobUrlMsg);
                    end else
                        Message(NotArchivedMsg);
                end;
            }
        }
        addafter(Preview_Promoted)
        {
            actionref(OpenFromBlob_Promoted; OpenFromBlob)
            {
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        LinkMapping: Record "Archive Link Mapping";
    begin
        IsArchivedToBlob := LinkMapping.Get(CopyStr(CompanyName(), 1, 30), Rec.SystemId);
    end;

    local procedure GetViewUrl(LinkMapping: Record "Archive Link Mapping"): Text
    var
        SasToken: Text;
    begin
        if LinkMapping."Blob Full URL" = '' then
            exit('');

        if not IsolatedStorage.Get('BLOB_ARCHIVE_SAS_TOKEN', DataScope::Company, SasToken) then
            exit(LinkMapping."Blob Full URL");

        if SasToken = '' then
            exit(LinkMapping."Blob Full URL");

        if not SasToken.StartsWith('?') then
            SasToken := '?' + SasToken;

        exit(LinkMapping."Blob Full URL" + SasToken);
    end;

    var
        IsArchivedToBlob: Boolean;
        NotArchivedMsg: Label 'This attachment has not been archived to Azure Blob Storage yet.';
        NoBlobUrlMsg: Label 'This attachment is recorded as archived, but no Azure Blob URL was found.';
}
