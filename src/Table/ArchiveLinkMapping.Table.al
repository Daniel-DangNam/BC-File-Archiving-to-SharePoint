namespace APSS.FileArchiving;

using System.Environment;

table 50143 "Archive Link Mapping"
{
    DataClassification = CustomerContent;
    Caption = 'Archive Link Mapping';

    fields
    {
        field(1; "Attachment SystemId"; Guid)
        {
            Caption = 'Attachment SystemId';
        }
        field(2; "Company Name"; Text[30])
        {
            Caption = 'Company Name';
            TableRelation = Company.Name;
        }
        field(3; "Source Table ID"; Integer)
        {
            Caption = 'Source Table ID';
        }
        field(4; "Source Document No."; Code[50])
        {
            Caption = 'Document No.';
        }
        field(5; "Source Line No."; Integer)
        {
            Caption = 'Line No.';
        }
        field(6; "File Name"; Text[250])
        {
            Caption = 'File Name';
        }
        field(10; "Blob Full URL"; Text[1000])
        {
            Caption = 'Blob Full URL';
            ExtendedDatatype = URL;
        }
        field(11; "Blob Relative Path"; Text[500])
        {
            Caption = 'Blob Relative Path';
        }
        field(12; "Is Purged In BC"; Boolean)
        {
            Caption = 'Is Binary Purged In BC';
        }
        field(13; "Archived DateTime"; DateTime)
        {
            Caption = 'Archived Date Time';
        }
    }

    keys
    {
        key(PK; "Company Name", "Attachment SystemId")
        {
            Clustered = true;
        }
        key(Idx_Doc; "Company Name", "Source Table ID", "Source Document No.", "Source Line No.")
        {
        }
    }
}
