using namespace System
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Linq
using namespace System.Reflection
using namespace System.Threading.Tasks
using namespace Microsoft.AspNetCore
using namespace Microsoft.AspNetCore.Hosting
using namespace Microsoft.AspNetCore.Mvc
using namespace Microsoft.AspNetCore.Mvc.Controllers
using namespace Microsoft.Extensions.Configuration
using namespace Microsoft.Extensions.Logging
using namespace Microsoft.AspNetCore.Builder
using namespace Microsoft.AspNetCore.Server.Kestrel.Core
using namespace Microsoft.Extensions.FileProviders
using namespace Microsoft.Extensions.DependencyInjection
using namespace Microsoft.AspNetCore.Mvc.ApplicationParts
using namespace PoshCode
$webroot = Join-Path $PSScriptRoot Web

[Produces("application/json")]
[Route("api/[controller]")]
class DateController : ControllerBase {
    [HttpGet()]
    [DateTimeOffset] Date() {
        return [DateTimeOffset]::UtcNow
    }
}

# class PowerShellControllerFactory : IControllerFactory {

#     CreateControllerFactory(ControllerActionDescriptor)
#     CreateControllerReleaser(ControllerActionDescriptor)
# }

# Manages the parts and features of an MVC application.
class PowerShellPartManager : ApplicationPartManager
{
    # The list of <see cref="IApplicationFeatureProvider"/>s.
    # [IList[IApplicationFeatureProvider]] get_FeatureProviders() {  }

    # The list of <see cref="ApplicationPart"/> instances.
    # [IList[ApplicationPart]] get_ApplicationParts {  }

    # Populates the given feature using the list of Features configured on the ApplicationPartManager
    # Cannot be overriden in PowerShell, because we don't have generics. Help me obiwan!
    # PowerShellClassesFailures
    # [void] PopulateFeature<TFeature>(TFeature feature)

    # [hidden] [void] PopulateDefaultParts()
    # {
    #     var entryAssembly = Assembly.Load(new AssemblyName(entryAssemblyName));
    #     var assembliesProvider = new ApplicationAssembliesProvider();
    #     var applicationAssemblies = assembliesProvider.ResolveAssemblies(entryAssembly);

    #     foreach (var assembly in applicationAssemblies)
    #     {
    #         var partFactory = ApplicationPartFactory.GetApplicationPartFactory(assembly);
    #         foreach (var part in partFactory.GetApplicationParts(assembly))
    #         {
    #             ApplicationParts.Add(part);
    #         }
    #     }
    # }

    PowerShellPartManager() {
        $partFactory = [ApplicationPartFactory]::GetApplicationPartFactory([DateController].Assembly);

        Write-Host "Looking for parts in $([DateController].Assembly.FullName)"
        foreach ($part in $partFactory.GetApplicationParts([DateController].Assembly))
        {
            Write-Host "Discovered $($part.Name) from $($part.Assembly.FullName)"
            $this.ApplicationParts.Add($part);
        }
    }
}

class Stella {
    [void] Configure([IApplicationBuilder]$app, [IHostingEnvironment]$env) {
        Write-Host "Configuring Polaris"
        # PowerShellClassesNeedExtensionMethods
        [PowerShellMiddlewareExtensions]::UseNewRunspace($app)
        [DeveloperExceptionPageExtensions]::UseDeveloperExceptionPage($app)
        if($Script:UseFileServer) {
            [FileServerExtensions]::UseFileServer($app, $true)
            # [DefaultFilesExtensions]::UseDefaultFiles($app)
            # [StaticFileExtensions]::UseStaticFiles($app)
            # [DirectoryBrowserExtensions]::UseDirectoryBrowser($app)
        }
        [MvcApplicationBuilderExtensions]::UseMvc($app) #WithDefaultRoute
        # $DirOptions = [DirectoryBrowserOptions]@{
        #     FileProvider = [PhysicalFileProvider]::new("C:\Users\Joel\Projects\Modules\TouchPS\Source\Web\")
        #     RequestPath = "/web"
        # }
        # [DirectoryBrowserExtensions]::UseDirectoryBrowser($app, $DirOptions)
    }

    [void] ConfigureServices([IServiceCollection]$svc) {
        Write-Host "Configuring Polaris Services with PowerShellPartManager"
        $svc = [ServiceCollectionServiceExtensions]::AddSingleton($svc, [ApplicationPartManager], [PowerShellPartManager]::new() )
        # [DirectoryBrowserServiceExtensions]::AddDirectoryBrowser($svc)
        $MvcBuilder = [MvcServiceCollectionExtensions]::AddMvc($svc)
        #$MvcBuilder = [MvcCoreServiceCollectionExtensions]::AddMvcCore($svc)
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
    $builder = [WebHostBuilderExtensions]::UseStartup($builder, [Stella])
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
        $options.ThreadCount = 1

        $options.Listen([IPAddress]::Any, 8080)

        # $options.Listen([IPAddress]::Any, 8081,
        # { param($listenOptions)
        #     $listenOptions.UseHttps("testCert.pfx", "testPassword");
        # });
    });

    # We need to put this runspace into each thread, like:
    # [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace = Get-Runspace

    $webhost = $builder.build()
    [WebHostExtensions]::Run($webhost)
    # $webhost.Start()
}