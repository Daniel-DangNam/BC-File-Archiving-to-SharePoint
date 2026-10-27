namespace APSS.FileArchiving;

enum 50141 "Purge Process Status"
{
    Extensible = false;
    Caption = 'Purge Process Status';

    value(0; NotEligible)
    {
        Caption = 'Not Eligible';
    }
    value(1; PendingApproval)
    {
        Caption = 'Pending Approval';
    }
    value(2; Approved)
    {
        Caption = 'Approved';
    }
    value(3; Rejected)
    {
        Caption = 'Rejected';
    }
    value(4; Expired)
    {
        Caption = 'Expired';
    }
    value(5; Purged)
    {
        Caption = 'Purged';
    }
    value(6; PurgeFailed)
    {
        Caption = 'Purge Failed';
    }
}
