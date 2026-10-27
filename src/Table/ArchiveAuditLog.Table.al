namespace APSS.FileArchiving;

table 50142 "Archive Audit Log"
{
    DataClassification = CustomerContent;
    Caption = 'Archive Audit Log';

    fields
    {
        field(1; "Log Entry No."; BigInteger)
        {
            AutoIncrement = true;
            Caption = 'Log Entry No.';
        }
        field(2; "Queue Entry No."; BigInteger)
        {
            Caption = 'Queue Entry No.';
            TableRelation = "Archive Queue Entry"."Entry No.";
        }
        field(3; "Company Name"; Text[30])
        {
            Caption = 'Company Name';
        }
        field(4; "Event DateTime"; DateTime)
        {
            Caption = 'Event Date Time';
        }
        field(5; "User ID"; Code[50])
        {
            Caption = 'User ID';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(6; "Action Type"; Enum "Archive Audit Action")
        {
            Caption = 'Action Type';
        }
        field(7; "Old Status"; Text[50])
        {
            Caption = 'Old Status';
        }
        field(8; "New Status"; Text[50])
        {
            Caption = 'New Status';
        }
        field(10; "Message"; Text[1000])
        {
            Caption = 'Log Message';
        }
        field(11; "Verification Proof"; Text[500])
        {
            Caption = 'Verification Proof (Size/Hash/Item ID)';
        }
    }

    keys
    {
        key(PK; "Log Entry No.")
        {
            Clustered = true;
        }
        key(Idx_Queue; "Queue Entry No.")
        {
        }
    }
}
