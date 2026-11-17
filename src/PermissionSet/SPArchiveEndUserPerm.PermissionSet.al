namespace APSS.FileArchiving;

permissionset 50141 SPArchiveEndUserPerm
{
    Assignable = true;
    Caption = 'Azure Blob Archive User', MaxLength = 30;
    Permissions =
        table "Archive Setup" = X,
        tabledata "Archive Setup" = R,
        table "Archive Link Mapping" = X,
        tabledata "Archive Link Mapping" = R,
        codeunit "Azure Blob Storage Client" = X;
}
