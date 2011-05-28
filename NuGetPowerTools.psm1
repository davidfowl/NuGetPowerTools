# Statement completion for project names
Register-TabExpansion 'Enable-PackageRestore' @{
    ProjectName = { Get-Project -All | Select -ExpandProperty Name }
}