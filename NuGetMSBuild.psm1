function Ensure-NuGetBuild {
    # Install the nuget command line if it doesn't exist
    $solutionDir = Get-SolutionDir
    $nugetToolsPath = (Join-Path $solutionDir .nuget)
    
    if(!(Test-Path $nugetToolsPath) -or !(Get-ChildItem $nugetToolsPath)) {
        Install-Package NuGet.Build -Source 'https://go.microsoft.com/fwlink/?LinkID=206669'
        $package = @(Get-Package NuGet.Build)[0]
        
        if(!$package) {
            return $false
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

    return $true
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
                 if($project.Type -eq 'Web Site') {
                    Write-Warning "Skipping '$($project.Name)', Website projects are not supported"
                    return
                 }
                 
                 if(!$initialized) {
                    # Make sure the nuget tools exists
                    $initialized = Ensure-NuGetBuild
                 }
                 
                 $project | Add-SolutionDirProperty
                 
                 $buildProject = $project | Get-MSBuildProject
                 if(!($buildProject.Xml.Imports | ?{ $_.Project -eq $targetsPath } )) {
                    $buildProject.Xml.AddImport($targetsPath) | Out-Null
                    $project.Save()
                    $buildProject.ReevaluateIfNecessary()

                    "Updated '$($project.Name)' to use 'NuGet.targets'"
                 }
                 else {
                    "'$($project.Name)' already imports 'NuGet.targets'"
                 }
                 $success = $true
            }
            catch {
                Write-Warning "Failed to add import 'NuGet.targets' to $($project.Name)"
            }
        }
    }
    End {
        if($success) {
            ""
            "*************************************************************************************"
            " INSTRUCTIONS"
            "*************************************************************************************"
            " - A .nuget folder has been added to your solution root. Make sure you check it in!"
            " - There is a NuGet.targets file in the .nuget folder that adds targets for "
            "   building and restoring packages."
            " - To enable building a package from a project, set <BuildPackage>true</BuildPackage>"
            "   in your project file."
            " - When you build your project, all of the packages in packages.config will be "
            "   restored. To disable restoring packages, set <RestorePackages>false</RestorePackages>"
            "   to your project (You'll need to check in packages when you do this)."
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