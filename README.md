# Overview
NuGetPowerTools is a collection of powershell modules that add useful functions for working with nuget inside Visual Studio.

# Installing
Using the [package](http://nuget.org/List/Packages/NuGetPowerTools) is good if you want to share these commands with all developers working on a particular project. Just do:

    Install-Package NuGetPowerTools

## NuGet profile
You can also manually import this module into your profile script, so that the functionality is always there.
Read more [here](http://docs.nuget.org/docs/start-here/using-the-package-manager-console#Setting_up_a_NuGet_Powershell_Profile)

# Using the package
## Package Restore and Build
NuGetPowerTools make it super easy to enable package restore and building a package from your project.

For restore, just type:

    Enable-PackageRestore
    
This command will add <RestorePackages>true</RestorePackages> in your project file(s).

For build:

    Enable-PackageBuild
    
This command will add <BuildPackage>true</BuildPackage> in your project file(s).

## How it works
Both restore and build will download nuget.exe and some custom build targets and will automatically hook your project up to use them.
It will store these in a .nuget folder (remember to check this in).
