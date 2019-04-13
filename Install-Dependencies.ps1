# Install-Package Microsoft.AspNetCore.App -RequiredVersion 2.2.4 -ProviderName NuGet -Destination $PSScriptRoot\bin -Source nuget.org -Force
nuget.exe install Microsoft.AspNetCore.App -Version 2.2.4 -OutputDirectory $PSScriptRoot\bin
Install-Module PSLambda