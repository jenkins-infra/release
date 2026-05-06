[CmdletBinding()]
Param()

$ProgressPreference = 'SilentlyContinue';
Set-PSDebug -Trace 1

# Artifact Signing Client Tools Installer - https://learn.microsoft.com/en-us/azure/artifact-signing/how-to-signing-integrations#installing-from-powershell
# TODO: pin version
# TODO: check if we can add to PATH during MSI installation
Invoke-WebRequest -Uri "https://download.microsoft.com/download/70ad2c3b-761f-4aa9-a9de-e7405aa2b4c1/ArtifactSigningClientTools.msi" -OutFile .\ArtifactSigningClientTools.msi;
Start-Process msiexec.exe -Wait -ArgumentList '/I ArtifactSigningClientTools.msi /quiet';
Remove-Item .\ArtifactSigningClientTools.msi;

# Download nuget package manager (required below)
Invoke-WebRequest -Uri https://dist.nuget.org/win-x86-commandline/latest/nuget.exe -OutFile .\nuget.exe

# Download and install SignTool - https://learn.microsoft.com/en-us/azure/artifact-signing/how-to-signing-integrations#download-and-install-signtool
.\nuget.exe install Microsoft.Windows.SDK.BuildTools -x

# Download and install the Artifact Signing dlib package: https://learn.microsoft.com/en-us/azure/artifact-signing/how-to-signing-integrations#download-and-install-the-artifact-signing-dlib-package
.\nuget.exe install Microsoft.ArtifactSigning.Client -x
