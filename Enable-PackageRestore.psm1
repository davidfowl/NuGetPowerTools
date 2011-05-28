function Ensure-NuGetCommandLine {
    # Install the nuget command line if it doesn't exist
    $solutionDir = Split-Path $dte.Solution.Properties.Item("Path").Value
    $nugetExePath = Join-Path (Join-Path $solutionDir tools) NuGet.exe
    
    if(!(Test-Path $nugetExePath)) {
        Install-Package NuGet.CommandLine
        $package = @(Get-Package NuGet.CommandLine)[0]
        
        # Get the repository path
        $componentModel = Get-VSComponentModel
        $repositorySettings = $componentModel.GetService([NuGet.VisualStudio.IRepositorySettings])
        $pathResolver = New-Object NuGet.DefaultPackagePathResolver($repositorySettings.RepositoryPath)
        $packagePath = $pathResolver.GetInstallPath($package)
        $packageExePath = Join-Path (Join-Path $packagePath tools) NuGet.exe
        
        "Moving NuGet.exe to tools\NuGet.exe, make sure you remember to check it into source control"
        
        $toolsPath = (Join-Path $solutionDir tools)
        if(!(Test-Path $toolsPath)) {
            mkdir $toolsPath | Out-Null
        }
        
        Move-Item $packageExePath $nugetExePath | Out-Null
        Remove-Item -Recurse -Force $packagePath
    }
}

function Apply-BeforeBuildTarget {
    param(
        $Project
    )
    
    function Get-MSBuildProject {
        param(
            $Project
        )
        
        # Get the msbuild loaded project
        $path = $Project.FullName
        return @([Microsoft.Build.Evaluation.ProjectCollection]::GlobalProjectCollection.GetLoadedProjects($path))[0]
    }
    
    # The restore command
    $restoreCommand = '"$(SolutionDir)tools\nuget" install "$(ProjectDir)packages.config" -o "$(SolutionDir)packages"'
    
    # Get the msbuild project
    $buildProject = Get-MSBuildProject $project
    
    # Try to resolve the before build target
    $beforeBuildTarget = $buildProject.Xml.Targets | ?{ $_.Name -eq 'BeforeBuild' }
    
    if(!$beforeBuildTarget) {
        # Add a new target if it isn't there
        $beforeBuildTarget = $buildProject.Xml.AddTarget("BeforeBuild")
    }
    
    # Now try to see if the exec task already exists
    $execTask = $beforeBuildTarget.Tasks | ?{ $_.Name -eq 'Exec' } | ?{ $command = $_.GetParameter("Command"); $command -eq $restoreCommand }
    
    if($execTask) {
        "Restore command already exists for '$($project.Name)'"
    }
    else {
        # It doesn't exist so create it
        $execTask = $beforeBuildTarget.AddTask("Exec")
        $execTask.SetParameter("Command", $restoreCommand)
        $execTask.SetParameter("WorkingDirectory", '$(MSBuildProjectDirectory)')
        $execTask.SetParameter("LogStandardErrorAsError", "true")
        $execTask.Condition = 'Exists(''$(MSBuildProjectDirectory)\packages.config'')'
        
        # Save the dte project so it doesn't cause a reload
        $project.Save()
        "Added restore command to '$($project.Name)'. Remember to exclude your packages folder from source control."
    }
}

function Enable-PackageRestore {
    param(
        [parameter(ValueFromPipelineByPropertyName = $true)]
        [string[]]$ProjectName
    )
    Process {
        # Make sure the NuGet.CommandLine exists
        Ensure-NuGetCommandLine
        
        if($ProjectName) {
            $projects = Get-Project $ProjectName
        }
        else {
            # All projects by default
            $projects = Get-Project -All
        }
        
        $projects | %{ 
            $project = $_
            try {
                 Apply-BeforeBuildTarget $project
            }
            catch {
                Write-Warning "Failed to add restore command to $($project.Name): $_"
            }
        }
    }
}