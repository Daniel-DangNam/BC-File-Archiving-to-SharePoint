namespace APSS.FileArchiving;

using Microsoft.EServices.EDocument;

pageextension 50142 "Inc Doc Attach FactBox Ext" extends "Incoming Doc. Attach. FactBox"
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
                ToolTip = 'Specifies whether this incoming attachment has been successfully archived to Azure Blob Storage.';
            }
        }
    }

    actions
    {
        addafter(Export)
        {
            action(OpenFromBlob)
            {
                ApplicationArea = All;
                Caption = 'Open from Azure Blob';
                Image = Web;
                Scope = Repeater;
                ToolTip = 'Opens the archived incoming document attachment directly in Azure Blob Storage via a secure SAS URL.';
                Enabled = IsArchivedToBlob;

                trigger OnAction()
                var
                    IncDocAttachment: Record "Incoming Document Attachment";
                    LinkMapping: Record "Archive Link Mapping";
                    ViewUrl: Text;
                begin
                    if not IncDocAttachment.Get(Rec."Incoming Document Entry No.", Rec."Line No.") then begin
                        Message(NotArchivedMsg);
                        exit;
                    end;

                    if not LinkMapping.Get(CopyStr(CompanyName(), 1, 30), IncDocAttachment.SystemId) then begin
                        Message(NotArchivedMsg);
                        exit;
                    end;

                    ViewUrl := GetViewUrl(LinkMapping);
                    if ViewUrl <> '' then
                        Hyperlink(ViewUrl)
                    else
                        Message(NoBlobUrlMsg);
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        IncDocAttachment: Record "Incoming Document Attachment";
        LinkMapping: Record "Archive Link Mapping";
    begin
        IsArchivedToBlob := false;
        if IncDocAttachment.Get(Rec."Incoming Document Entry No.", Rec."Line No.") then
            IsArchivedToBlob := LinkMapping.Get(CopyStr(CompanyName(), 1, 30), IncDocAttachment.SystemId);
    end;

    local procedure GetViewUrl(LinkMapping: Record "Archive Link Mapping"): Text
    var
        SasToken: SecretText;
        TokenText: Text;
    begin
        if LinkMapping."Blob Full URL" = '' then
            exit('');

        if not IsolatedStorage.Get('BLOB_ARCHIVE_SAS_TOKEN', DataScope::Company, SasToken) then
            exit(LinkMapping."Blob Full URL");

        TokenText := SasToken.Unwrap();
        if TokenText = '' then
            exit(LinkMapping."Blob Full URL");

        if not TokenText.StartsWith('?') then
            TokenText := '?' + TokenText;

        exit(LinkMapping."Blob Full URL" + TokenText);
    end;

    var
        IsArchivedToBlob: Boolean;
        NotArchivedMsg: Label 'This incoming document attachment has not been archived to Azure Blob Storage yet.';
        NoBlobUrlMsg: Label 'This attachment is recorded as archived, but no Azure Blob URL was found.';
}
