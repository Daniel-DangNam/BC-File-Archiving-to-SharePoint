namespace APSS.FileArchiving;

using System.Environment;

table 50141 "Archive Queue Entry"
{
    DataClassification = CustomerContent;
    Caption = 'Archive Queue Entry';

    fields
    {
        field(1; "Entry No."; BigInteger)
        {
            AutoIncrement = true;
            Caption = 'Entry No.';
        }
        field(2; "Deterministic Archive Key"; Text[128])
        {
            Caption = 'Deterministic Archive Key (Hash)';
        }
        field(3; "Company Name"; Text[30])
        {
            Caption = 'Company Name';
            TableRelation = Company.Name;
        }
        field(4; "Source Table ID"; Integer)
        {
            Caption = 'Source Table ID';
        }
        field(5; "Source Record SystemId"; Guid)
        {
            Caption = 'Source Document Record SystemId';
        }
        field(6; "Attachment SystemId"; Guid)
        {
            Caption = 'Attachment SystemId';
        }
        field(7; "Source Document Type"; Code[30])
        {
            Caption = 'Document Type';
        }
        field(8; "Source Document No."; Code[50])
        {
            Caption = 'Document No.';
        }
        field(9; "Source Line No."; Integer)
        {
            Caption = 'Line No.';
        }
        field(10; "Source Attachment ID"; Integer)
        {
            Caption = 'Attachment ID / Entry No.';
        }
        field(20; "File Name"; Text[250])
        {
            Caption = 'Original File Name';
        }
        field(21; "File Extension"; Text[30])
        {
            Caption = 'File Extension';
        }
        field(22; "Original File Size (Bytes)"; BigInteger)
        {
            Caption = 'Original File Size (Bytes)';
        }
        field(23; "File Hash / Checksum"; Text[64])
        {
            Caption = 'Calculated Checksum (SHA-256 / QuickXorHash)';
        }
        field(30; "Archive Status"; Enum "Archive Process Status")
        {
            Caption = 'Archive Status';
        }
        field(31; "Purge Status"; Enum "Purge Process Status")
        {
            Caption = 'Purge Status';
        }
        field(40; "SharePoint Relative Path"; Text[500])
        {
            Caption = 'SharePoint Relative Path';
        }
        field(41; "SharePoint Item ID"; Text[250])
        {
            Caption = 'SharePoint Drive Item ID';
        }
        field(42; "SharePoint Web URL"; Text[1000])
        {
            Caption = 'SharePoint Web URL';
            ExtendedDatatype = URL;
        }
        field(43; "SharePoint ETag"; Text[150])
        {
            Caption = 'SharePoint ETag / Version';
        }
        field(50; "Retry Count"; Integer)
        {
            Caption = 'Retry Count';
            InitValue = 0;
        }
        field(51; "Max Retries"; Integer)
        {
            Caption = 'Max Retries';
            InitValue = 5;
        }
        field(52; "Last Error Message"; Text[1000])
        {
            Caption = 'Last Error Message';
        }
        field(60; "Queued DateTime"; DateTime)
        {
            Caption = 'Queued DateTime';
        }
        field(61; "Uploaded DateTime"; DateTime)
        {
            Caption = 'Uploaded DateTime';
        }
        field(62; "Verified DateTime"; DateTime)
        {
            Caption = 'Verified DateTime';
        }
        field(63; "Approved DateTime"; DateTime)
        {
            Caption = 'Approved DateTime';
        }
        field(64; "Approved By User"; Code[50])
        {
            Caption = 'Approved By User';
        }
        field(65; "Purged DateTime"; DateTime)
        {
            Caption = 'Purged DateTime';
        }
        field(70; "Source Record Exists"; Boolean)
        {
            Caption = 'Source Document Exists';
            InitValue = true;
        }
        field(71; "Is Shared Media"; Boolean)
        {
            Caption = 'Is Shared Media Reference';
        }
        field(72; "Is Dry Run"; Boolean)
        {
            Caption = 'Is Dry Run Record';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        key(Idx_Key; "Deterministic Archive Key")
        {
            Unique = true;
        }
        key(Idx_Status; "Archive Status", "Purge Status")
        {
        }
        key(Idx_CompanyDoc; "Company Name", "Source Table ID", "Source Document No.")
        {
        }
    }
}
