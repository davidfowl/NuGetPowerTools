function Ensure-NuGetBuild {
    # Install the nuget command line if it doesn't exist
    $solutionDir = Get-SolutionDir
    $nugetToolsPath = (Join-Path $solutionDir .nuget)
    
    if(!(Test-Path $nugetToolsPath) -or !(Get-ChildItem $nugetToolsPath)) {
        Install-Package NuGet.Build -Source 'https://go.microsoft.com/fwlink/?LinkID=206669'
        $package = @(Get-Package NuGet.Build)[0]
        
        if(!$package) {
            Write-Error "Unable to locate NuGet.Build"
            return
        }
        
        # Get the repository path
        $componentModel = Get-VSComponentModel
        $repositorySettings = $componentModel.GetService([NuGet.VisualStudio.IRepositorySettings])
        $pathResolver = New-Object NuGet.DefaultPackagePathResolver($repositorySettings.RepositoryPath)
        $packagePath = $pathResolver.GetInstallPath($package)
        
        if(!(Test-Path $nugetToolsPath)) {
            mkdir $nugetToolsPath | Out-Null
        }
        
        Copy-Item "$packagePath\tools\*.*" $nugetToolsPath -Force | Out-Null
        Uninstall-Package NuGet.Build
    }
}

function Use-NuGetBuild {
    param(
        [parameter(ValueFromPipelineByPropertyName = $true)]
        [string[]]$ProjectName
    )
    Begin {
        $success = $false
    }
    Process {
        # Make sure the nuget tools exists
        Ensure-NuGetBuild
        
        if($ProjectName) {
            $projects = Get-Project $ProjectName
        }
        else {
            # All projects by default
            $projects = Get-Project -All
        }

        if(!$projects) {
            Write-Error "Unable to locate project. Make sure it isn't unloaded."
            return
        }
        
        $targetsPath = '$(SolutionDir)\.nuget\NuGet.targets'
        
        $projects | %{ 
            $project = $_
            try {
                 $project | Add-SolutionDirProperty
                 
                 $buildProject = $project | Get-MSBuildProject
                 if(!($buildProject.Xml.Imports | ?{ $_.Project -eq $targetsPath } )) {
                    $buildProject.Xml.AddImport($targetsPath) | Out-Null
                    $project.Save()
                    $buildProject.ReevaluateIfNecessary()

                    "Enabled package restore for '$($project.Name)'"
                 }
                 else {
                    "Package restore already enabled for '$($project.Name)'"
                 }
            }
            catch {
                Write-Warning "Failed to enable package restore for $($project.Name)"
            }
        }

        $success = $true
    }
    End {
        if($success) {
            ""
            "*************************************************************************************"
            " INSTRUCTIONS"
            "*************************************************************************************"
            " - A .nuget folder has been added to your solution root. Make sure you check it in!"
            " - There is a NuGet.targets file in the .nuget folder that adds some targets for"
            "   building and restoring packages."
            " - When you build your project, all of the packages in packages.config will be restored."
            "   You can remove 'packages' (at solution level) from source control."
            " - To disable restoring packages, add <RestorePackages>false</RestorePackages>"
            "   to your project (You'll need to check in packages when you do this)."
            " - To customize package sources used to restore, change the 'PackageSources' property in"
            "   .nuget/NuGet.targets"
            " - To enable building a package from a project, set  <BuildPackage>true</BuildPackage>"
            "   in your project file"
            "*************************************************************************************"
            ""
        }
    }
}

# Statement completion for project names
Register-TabExpansion 'Use-NuGetBuild' @{
    ProjectName = { Get-Project -All | Select -ExpandProperty Name }
}

Export-ModuleMember Use-NuGetBuild