namespace APSS.FileArchiving;

enum 50142 "Archive Audit Action"
{
    Extensible = false;
    Caption = 'Archive Audit Action';

    value(0; DryRun)
    {
        Caption = 'Dry Run';
    }
    value(1; Queued)
    {
        Caption = 'Queued';
    }
    value(2; UploadStarted)
    {
        Caption = 'Upload Started';
    }
    value(3; UploadSucceeded)
    {
        Caption = 'Upload Succeeded';
    }
    value(4; VerifySucceeded)
    {
        Caption = 'Verify Succeeded';
    }
    value(5; VerifyFailed)
    {
        Caption = 'Verify Failed';
    }
    value(6; PurgeRequested)
    {
        Caption = 'Purge Requested';
    }
    value(7; PurgeApproved)
    {
        Caption = 'Purge Approved';
    }
    value(8; PurgeRejected)
    {
        Caption = 'Purge Rejected';
    }
    value(9; PurgeCompleted)
    {
        Caption = 'Purge Completed';
    }
    value(10; Error)
    {
        Caption = 'Error';
    }
}
