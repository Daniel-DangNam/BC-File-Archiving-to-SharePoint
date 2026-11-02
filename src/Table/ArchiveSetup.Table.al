namespace APSS.FileArchiving;

using System.Security.AccessControl;

table 50140 "Archive Setup"
{
    DataClassification = CustomerContent;
    Caption = 'Archive Setup';

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key';
        }
        field(10; "Storage Account Name"; Text[100])
        {
            Caption = 'Azure Storage Account Name';
        }
        field(11; "Container Name"; Text[100])
        {
            Caption = 'Blob Container Name';
        }
        field(12; "Base Folder Path"; Text[250])
        {
            Caption = 'Base Folder Path';
        }
        field(13; "Default Access Tier"; Option)
        {
            Caption = 'Default Access Tier';
            OptionMembers = "Cool","Hot","Cold","Archive";
            OptionCaption = 'Cool,Hot,Cold,Archive';
            InitValue = "Cool";
        }
        field(20; "Cut-Off Date Rule"; Option)
        {
            Caption = 'Cut-Off Date Evaluation Rule';
            OptionMembers = "Posting Date","Document Date";
            OptionCaption = 'Posting Date,Document Date';
            InitValue = "Posting Date";
        }
        field(21; "Batch Size"; Integer)
        {
            Caption = 'Batch Size (per Job Run)';
            InitValue = 50;
            MinValue = 1;
            MaxValue = 500;
        }
        field(22; "Chunk Size (MB)"; Integer)
        {
            Caption = 'Chunk Size for Block Upload (MB)';
            InitValue = 4;
            MinValue = 1;
            MaxValue = 100;
        }
        field(30; "Require Secondary Approval"; Boolean)
        {
            Caption = 'Require Secondary Approval for Purge';
            InitValue = true;
        }
        field(31; "Approver Role ID"; Code[20])
        {
            Caption = 'Approver Permission Role ID';
            TableRelation = "Aggregate Permission Set"."Role ID";
        }
        field(32; "Approval Expiry (Days)"; Integer)
        {
            Caption = 'Approval Expiry (Days)';
            InitValue = 7;
        }
        field(33; "WORM Policy Enabled"; Boolean)
        {
            Caption = 'WORM Policy Enabled (Configurable)';
            InitValue = false;
        }
        field(34; "WORM Policy Locked"; Boolean)
        {
            Caption = 'WORM Policy Locked (Irreversible)';
            InitValue = false;
        }
        field(40; "Is Configured"; Boolean)
        {
            Caption = 'Is Configured';
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }
}
