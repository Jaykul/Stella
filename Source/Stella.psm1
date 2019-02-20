using namespace System
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Linq
using namespace System.Threading.Tasks
using namespace Microsoft.AspNetCore
using namespace Microsoft.AspNetCore.Hosting
using namespace Microsoft.AspNetCore.Mvc
using namespace Microsoft.Extensions.Configuration
using namespace Microsoft.Extensions.Logging
using namespace Microsoft.AspNetCore.Builder
using namespace Microsoft.AspNetCore.Server.Kestrel.Core
using namespace Microsoft.Extensions.FileProviders
using namespace Microsoft.Extensions.DependencyInjection

$webroot = Join-Path $PSScriptRoot Web

class Polaris {
    [void] Configure([IApplicationBuilder]$app, [IHostingEnvironment]$env) {
        Write-Host "Configuring Polaris"
        if($Script:UseFileServer) {
            [FileServerExtensions]::UseFileServer($app, $true)
        }
        # [DefaultFilesExtensions]::UseDefaultFiles($app)
        # [StaticFileExtensions]::UseStaticFiles($app)
        # [DirectoryBrowserExtensions]::UseDirectoryBrowser($app)
        # [MvcApplicationBuilderExtensions]::UseMvcWithDefaultRoute($app)
        # $DirOptions = [DirectoryBrowserOptions]@{
        #     FileProvider = [PhysicalFileProvider]::new("C:\Users\Joel\Projects\Modules\TouchPS\Source\Web\")
        #     RequestPath = "/web"
        # }
        # [DirectoryBrowserExtensions]::UseDirectoryBrowser($app, $DirOptions)
    }

    [void] ConfigureServices([IServiceCollection]$svc) {
        Write-Host "Configuring Polaris Services"
        # [DirectoryBrowserServiceExtensions]::AddDirectoryBrowser($svc)
        #[MvcServiceCollectionExtensions]::AddMvc($svc)
    }
}

class Api : Controller {
    [HttpGet()]
    [string] Date() {
        return [DateTimeOffset]::UtcNow.ToString("o")
    }
}

function Start-Stella {
    [CmdletBinding()]
    param(
        # ASP.NET likes to know a root folder to look in for views, etc. By default uses "WebSite" in the module
        [string]$ContentRoot = $(Join-Path $PSScriptRoot WebSite),
        # Static files may be served from here (defaults to $ContentRoot\wwwroot)
        [string]$WebRoot
    )

    $builder = [WebHostBuilder]::new()
    $builder = [WebHostBuilderExtensions]::UseStartup($builder, [Polaris])
    $builder = [HostingAbstractionsWebHostBuilderExtensions]::UseContentRoot($builder, $ContentRoot)
    if($WebRoot) {
        $Script:UseFileServer = $true
        $builder = [HostingAbstractionsWebHostBuilderExtensions]::UseWebRoot($builder, $WebRoot)
    } else {
        $Script:UseFileServer = Test-Path (Join-Path $ContentRoot wwwroot)
    }
    $builder = [WebHostBuilderKestrelExtensions]::UseKestrel($builder)
    $builder = [WebHostBuilderKestrelExtensions]::ConfigureKestrel($builder,
    [Action[WebHostBuilderContext,KestrelServerOptions]]{
        param($context, $options)

        $options.Limits.MaxConcurrentConnections = 100
        $options.Limits.MaxConcurrentUpgradedConnections = 100
        $options.Limits.MaxRequestBodySize = 10 * 1024
        $options.Limits.MinRequestBodyDataRate = [MinDataRate]::new(100, "00:00:10")
        $options.Limits.MinResponseDataRate = [MinDataRate]::new(100, "00:00:10")

        $options.Listen([IPAddress]::Any, 8080)

        # $options.Listen([IPAddress]::Loopback, 5001, listenOptions =>
        # {
        #     listenOptions.UseHttps("testCert.pfx", "testPassword");
        # });
    });


    $webhost = $builder.build()
    [WebHostExtensions]::Run($webhost)
    # $webhost.Start()
}