namespace APSS.FileArchiving;

enum 50140 "Archive Process Status"
{
    Extensible = false;
    Caption = 'Archive Process Status';

    value(0; Draft)
    {
        Caption = 'Draft / Preview';
    }
    value(1; PendingUpload)
    {
        Caption = 'Pending Upload';
    }
    value(2; Uploading)
    {
        Caption = 'Uploading';
    }
    value(3; Uploaded)
    {
        Caption = 'Uploaded';
    }
    value(4; Verified)
    {
        Caption = 'Verified';
    }
    value(5; Failed)
    {
        Caption = 'Failed';
    }
    value(6; SkippedOrphan)
    {
        Caption = 'Skipped / Orphan';
    }
}
