function Ensure-NuGetTools {
    # Install the nuget command line if it doesn't exist
    $solutionDir = Get-SolutionDir
    $nugetExePath = Join-Path (Join-Path $solutionDir nuget) NuGet.exe
    
    if(!(Test-Path $nugetExePath)) {
        Install-Package NuGet.CommandLine
        $package = @(Get-Package NuGet.CommandLine)[0]
        
        # Get the repository path
        $componentModel = Get-VSComponentModel
        $repositorySettings = $componentModel.GetService([NuGet.VisualStudio.IRepositorySettings])
        $pathResolver = New-Object NuGet.DefaultPackagePathResolver($repositorySettings.RepositoryPath)
        $packagePath = $pathResolver.GetInstallPath($package)
        $packageExePath = Join-Path (Join-Path $packagePath tools) NuGet.exe
        
        "Moving NuGet.exe to nuget\NuGet.exe, make sure you remember to check it into source control"
        
        $toolsPath = (Join-Path $solutionDir nuget)
        if(!(Test-Path $toolsPath)) {
            mkdir $toolsPath | Out-Null
        }
        
        Move-Item $packageExePath $nugetExePath | Out-Null
        Remove-Item -Recurse -Force $packagePath
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