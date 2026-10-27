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
        field(10; "Tenant ID"; Text[50])
        {
            Caption = 'Microsoft Entra Tenant ID';
        }
        field(11; "Client ID"; Text[50])
        {
            Caption = 'App Registration Client ID';
        }
        field(12; "SharePoint Site ID"; Text[150])
        {
            Caption = 'SharePoint Site ID (Graph)';
        }
        field(13; "SharePoint Drive ID"; Text[150])
        {
            Caption = 'Document Library (Drive ID)';
        }
        field(14; "Base Folder Path"; Text[250])
        {
            Caption = 'Base Folder Path';
        }
        field(20; "Cut-Off Date Rule"; Option)
        {
            Caption = 'Cut-Off Date Evaluation Rule';
            OptionMembers = "Posting Date","Document Date","Attached Date";
            OptionCaption = 'Posting Date,Document Date,Attached Date';
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
            Caption = 'Chunk Size for Resumable Upload (MB)';
            InitValue = 4;
            MinValue = 4;
            MaxValue = 60;
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
