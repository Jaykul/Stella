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
            # [DefaultFilesExtensions]::UseDefaultFiles($app)
            # [StaticFileExtensions]::UseStaticFiles($app)
            # [DirectoryBrowserExtensions]::UseDirectoryBrowser($app)
        }
        # [MvcApplicationBuilderExtensions]::UseMvc($app) #WithDefaultRoute
        # $DirOptions = [DirectoryBrowserOptions]@{
        #     FileProvider = [PhysicalFileProvider]::new("C:\Users\Joel\Projects\Modules\TouchPS\Source\Web\")
        #     RequestPath = "/web"
        # }
        # [DirectoryBrowserExtensions]::UseDirectoryBrowser($app, $DirOptions)
    }

    [void] ConfigureServices([IServiceCollection]$svc) {
        Write-Host "Configuring Polaris Services"
        # [DirectoryBrowserServiceExtensions]::AddDirectoryBrowser($svc)
        # $MvcBuilder = [MvcServiceCollectionExtensions]::AddMvc($svc)
        # $MvcBuilder = [MvcCoreMvcBuilderExtensions]::ConfigureApplicationPartManager($MvcBuilder,
        #     [Action[Microsoft.AspNetCore.Mvc.ApplicationParts.ApplicationPartManager]]{
        #         param($PartManager)
        #         Write-Host "Manage Parts"
        #         if($asm = $PartManager.ApplicationParts.Where({$_.Name -match 'PowerShell Class Assembly'}, "First", 1)) {
        #             Write-Host "Remove $($asm.Name)"
        #             $PartManager.ApplicationParts.Remove($asm)
        #         }
        #     })
    }
}

# if (!("PolarisPartManater" -as [type])) {

#     add-type @"
# using System;
# using System.Collections.Generic;
# using System.Linq;
# using System.Reflection;
# using Microsoft.AspNetCore.Mvc.ApplicationParts;

# public class PolarisPartManager : ApplicationPartManager {

#     new public void PopulateDefaultParts(string entryAssemblyName)
#     {
#         AppDomain.CurrentDomain.GetAssemblies()
#             var entryAssembly = Assembly.Load(new AssemblyName(entryAssemblyName));
#             var assembliesProvider = new ApplicationAssembliesProvider();
#             var applicationAssemblies = assembliesProvider.ResolveAssemblies(entryAssembly);

#             foreach (var assembly in applicationAssemblies)
#             {
#                 var partFactory = ApplicationPartFactory.GetApplicationPartFactory(assembly);
#                 foreach (var part in partFactory.GetApplicationParts(assembly))
#                 {
#                     ApplicationParts.Add(part);
#                 }
#             }
#     }
# }
# "@

# }


# [Produces("application/json")]
# [Route("api/[controller]")]
# class DateController : ControllerBase {

#     [HttpGet()]
#     [DateTimeOffset] Date() {
#         return [DateTimeOffset]::UtcNow
#     }
# }

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
    # https://docs.microsoft.com/en-us/aspnet/core/fundamentals/servers/kestrel
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

        # $options.Listen([IPAddress]::Any, 8081,
        # { param($listenOptions)
        #     $listenOptions.UseHttps("testCert.pfx", "testPassword");
        # });
    });


    $webhost = $builder.build()
    [WebHostExtensions]::Run($webhost)
    # $webhost.Start()
}