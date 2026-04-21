[CmdletBinding()]
Param(
  # TODO: detect signtool.exe automatically to avoid bad surprise when the version changes
  [String] $SigntoolPath    = ".\Microsoft.Windows.SDK.BuildTools\bin\10.0.28000.0\x64\signtool.exe",
  [String] $CodeSigningDlibPath = ".\Microsoft.ArtifactSigning.Client\bin\x64\Azure.CodeSigning.Dlib.dll",
  [String] $MSIPath = ".\release\msi\build\bin\Release\en-US\jenkins*.msi"
)

$ProgressPreference = 'SilentlyContinue';
Set-PSDebug -Trace 1

$MetadataPath = ".\metadata.json"
@"
{
  "Endpoint": "https://eus.codesigning.azure.net/",
  "CodeSigningAccountName": "LFOpenSourceLLC-Signing",
  "CertificateProfileName": "CDF-Jenkins"
}
"@ | Set-Content $MetadataPath

# Require Azure SD authentication (default to environment variables AZURE_TENANT_ID, AZURE_CLIENT_ID and AZURE_CLIENT_SECRET)
& $SigntoolPath sign /v /debug /fd SHA256 /tr "http://timestamp.acs.microsoft.com" /td SHA256 /dlib $CodeSigningDlibPath /dmdf $MetadataPath $MSIPath
