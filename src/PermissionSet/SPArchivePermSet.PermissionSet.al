namespace APSS.FileArchiving;

permissionset 50140 SPArchivePermSet
{
    Assignable = true;
    Caption = 'SharePoint Archiving Perms', MaxLength = 30;
    Permissions =
        table "Archive Setup" = X,
        tabledata "Archive Setup" = RMID,
        table "Archive Queue Entry" = X,
        tabledata "Archive Queue Entry" = RMID,
        table "Archive Audit Log" = X,
        tabledata "Archive Audit Log" = RMID,
        table "Archive Link Mapping" = X,
        tabledata "Archive Link Mapping" = RMID,
        page "Archive Setup" = X,
        page "Archive Queue Entries" = X,
        page "Archive Audit Logs" = X,
        codeunit "Archive Dry-Run Scanner" = X,
        codeunit "SP Archive Graph Client" = X;
}
