function Ensure-NuGetTools {
    # Install the nuget command line if it doesn't exist
    $solutionDir = Get-SolutionDir
    $nugetToolsPath = (Join-Path $solutionDir nuget)
    
    if(!(Test-Path $nugetToolsPath)) {
        Install-Package NuGet.Build -Source 'https://go.microsoft.com/fwlink/?LinkID=206669'
        $package = @(Get-Package NuGet.Build)[0]
        
        # Get the repository path
        $componentModel = Get-VSComponentModel
        $repositorySettings = $componentModel.GetService([NuGet.VisualStudio.IRepositorySettings])
        $pathResolver = New-Object NuGet.DefaultPackagePathResolver($repositorySettings.RepositoryPath)
        $packagePath = $pathResolver.GetInstallPath($package)
        
        Write-Warning "Remember to check the nuget directory into source control!"
        
        if(!(Test-Path $nugetToolsPath)) {
            mkdir $nugetToolsPath | Out-Null
        }
        
        Copy-Item "$packagePath\tools\*.*" $nugetToolsPath | Out-Null
        Uninstall-Package NuGet.Build
    }
}

function Enable-PackageRestore {
    param(
        [parameter(ValueFromPipelineByPropertyName = $true)]
        [string[]]$ProjectName
    )
    Process {
        # Make sure the nuget tools exists
        Ensure-NuGetTools
        
        if($ProjectName) {
            $projects = Get-Project $ProjectName
        }
        else {
            # All projects by default
            $projects = Get-Project -All
        }
        
        $targetsPath = '$(SolutionDir)\nuget\NuGet.targets'
        
        $projects | %{ 
            $project = $_
            try {
                 $project | Add-SolutionDirProperty
                 
                 $buildProject = $project | Get-MSBuildProject
                 if(!($buildProject.Xml.Imports | ?{ $_.Project -eq $targetsPath } )) {
                    $buildProject.Xml.AddImport($targetsPath) | Out-Null
                    $project.Save()
                    "Added restore command to '$($project.Name)'"
                 }
                 else {
                    "Restore command already configured for '$($project.Name)'"
                 }
            }
            catch {
                Write-Warning "Failed to add restore command to $($project.Name)"
            }
        }
    }
}

# Statement completion for project names
Register-TabExpansion 'Enable-PackageRestore' @{
    ProjectName = { Get-Project -All | Select -ExpandProperty Name }
}

Export-ModuleMember Enable-PackageRestore