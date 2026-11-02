namespace APSS.FileArchiving;

permissionset 50140 SPArchivePermSet
{
    Assignable = true;
    Caption = 'Azure Blob Archiving Perms', MaxLength = 30;
    Permissions =
        table "Archive Setup" = X,
        tabledata "Archive Setup" = RMID,
        table "Archive Queue Entry" = X,
        tabledata "Archive Queue Entry" = RMID,
        table "Archive Audit Log" = X,
        tabledata "Archive Audit Log" = RMID,
        table "Archive Link Mapping" = X,
        tabledata "Archive Link Mapping" = RMID,
        page "Azure Blob Archive Setup" = X,
        page "Azure Blob Archive Queue" = X,
        page "Azure Blob Archive Audit Logs" = X,
        codeunit "Archive Dry-Run Scanner" = X,
        codeunit "Azure Blob Storage Client" = X;
}
