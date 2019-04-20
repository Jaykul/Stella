using namespace System
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Linq
using namespace System.Reflection
using namespace System.Threading
using namespace System.Threading.Tasks
using namespace System.Management.Automation
using namespace Microsoft.AspNetCore
using namespace Microsoft.AspNetCore.Hosting
using namespace Microsoft.AspNetCore.Hosting.Internal
using namespace Microsoft.AspNetCore.Mvc
using namespace Microsoft.AspNetCore.Mvc.Controllers
using namespace Microsoft.Extensions.Configuration
using namespace Microsoft.Extensions.Logging
using namespace Microsoft.Extensions.Logging.Console
using namespace Microsoft.AspNetCore.Builder
using namespace Microsoft.AspNetCore.Server.Kestrel.Core
using namespace Microsoft.Extensions.FileProviders
using namespace Microsoft.Extensions.DependencyInjection
using namespace Microsoft.AspNetCore.Mvc.ApplicationParts
using namespace Microsoft.AspNetCore.Routing
using namespace Microsoft.AspNetCore.Routing.Internal
using namespace Microsoft.AspNetCore.Routing.Patterns
using namespace Microsoft.AspNetCore.Routing.Constraints
using namespace Microsoft.AspNetCore.Http
using namespace Swashbuckle.AspNetCore.Swagger
using namespace Swashbuckle.AspNetCore.SwaggerGen
using namespace Swashbuckle.AspNetCore.SwaggerUI

$webroot = Join-Path $PSScriptRoot Web

[Produces("application/json")]
[Route("api/[controller]")]
class DateController : ControllerBase {
    
    $DefaultRunspace = [RunspaceFactory]::CreateRunspace()
    
    DateController() {}
    
    [HttpGet()]
    [DateTimeOffset] Date() {
        Write-Host "[DateController] Invoking method Date() " -Foreground White -Background Green
        return [DateTimeOffset]::UtcNow
    }

    [HttpGet("/home")] 
    [ContentResult] Index() {        
        [Runspace]::DefaultRunspace = $this.DefaultRunspace
        Write-Host "[HomeController] Index" -ForegroundColor White -BackgroundColor DarkMagenta
        return [ContentResult]@{
            Content = ( Get-ChildItem -Path ~ | ConvertTo-Html -As Table )
            ContentType = "text/html"
        }
    }
}


# Manages the parts and features of an MVC application.
class PowerShellPartManager : ApplicationPartManager {
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

    hidden [IConfiguration]       $configuration
    hidden [IHostingEnvironment]  $environment
    hidden [ILoggerFactory]       $loggerFactory
    hidden [ILogger]              $logger

    Stella([IConfiguration] $configuration, [IHostingEnvironment] $environment, [ILoggerFactory] $loggerFactory) {
        Write-Host "Creating Stella Instance" -Foreground Magenta
        $this.configuration      = $configuration
        $this.environment        = $environment
        $this.loggerFactory      = $loggerFactory 
        $this.logger             = $loggerFactory.CreateLogger($this.GetType()) 
        [Stella]::WriteAvailableMethods('Environment', $this.environment)
        [Stella]::WriteAvailableMethods('Configuration', $this.configuration)
        [Stella]::WriteAvailableMethods('LoggerFactory', $this.loggerFactory)
        [Stella]::WriteAvailableMethods('Logger', $this.logger)
    }
    
    [void] ConfigureServices([IServiceCollection]$svc) {
        Write-Host "Configure Stella Services" -Foreground Magenta
        [Stella]::WriteAvailableMethods('svc', $svc)
        
        $svc.AddLogging([Action[ILoggingBuilder]]{
            param($loggingBuilder)
            [Stella]::WriteAvailableMethods('LoggingBuilder', $loggingBuilder)
            $loggingBuilder.ClearProviders()> $null
            
            # Disable Internal WebHost Error because Assembly loading error # need verification
            # $loggingBuilder.AddFilter('Microsoft.AspNetCore.Hosting.Internal.WebHost', [LogLevel]::None)
            
            $loggingBuilder.AddConsole([Action[ConsoleLoggerOptions]]{ param($options) $options.IncludeScopes = $true}) > $null
            
            # $loggingBuilder.SetMinimumLevel([LogLevel]::Error)  > $null
            $loggingBuilder.SetMinimumLevel([LogLevel]::Trace)  > $null
        })
        
        $partManager = [PowerShellPartManager]::new()
        $svc.AddSingleton([ApplicationPartManager],$partManager )
        $svc.AddSingleton([PowerShellPartManager], $partManager)
        $svc.AddSingleton([DateController], [DateController]::new())
              
        $endpointDataSource = [DefaultEndpointDataSource]::new(@(
            [RouteEndpoint]::new(
                [RequestDelegate][PSDelegate]{
                    param([HttpContext] $httpContext)
                    [Console]::WriteLine("DefaultEndpointDataSource One")
                    [HttpResponse] $response = $httpContext.Response
                    [Task] $task = [HttpResponseWritingExtensions]::WriteAsync($response, 'DefaultEndpointDataSource One', [CancellationToken]::None)
                    $task.GetAwaiter()
                    return $task
                },
                [RoutePatternFactory]::Parse("/1"),
                0,
                [EndpointMetadataCollection]::Empty,
                "Home"
            ),
            [RouteEndpoint]::new(
                [RequestDelegate][PSDelegate]{
                    param([HttpContext] $httpContext)
                    [Console]::WriteLine("DefaultEndpointDataSource Two")
                    
                    [HttpResponse] $response = $httpContext.Response
                    [IServiceProvider] $requestServices = $httpContext.RequestServices
                    
                    [Console]::WriteLine("StreamWriter new")
                    $writer = [StreamWriter]::new(
                        $response.Body,
                        [System.Text.Encoding]::UTF8,
                        1024,
                        $true # leaveOpen
                    )

                    [Console]::WriteLine("GetRequiredService DfaGraphWriter")
                    $graphWriter = [ServiceProviderServiceExtensions]::GetRequiredService($requestServices, [DfaGraphWriter]) -as [DfaGraphWriter] 
                    
                    [Console]::WriteLine("GetRequiredService CompositeEndpointDataSource")
                    $dataSource = [ServiceProviderServiceExtensions]::GetRequiredService($requestServices, [CompositeEndpointDataSource]) -as [CompositeEndpointDataSource] 
                    
                    [Console]::WriteLine("graphWriter Write")
                    $graphWriter.Write($dataSource, $writer)
                    $writer.Dispose()

                    return [Task]::CompletedTask
                },
                [RoutePatternFactory]::Parse("/2"),
                0,
                [EndpointMetadataCollection]::new(@(
                    [HttpMethodMetadata]::new([string[]]"GET")
                )),
                "DFA Graph"
            )
        ))
        $svc.TryAddEnumerable( [ServiceDescriptor]::Singleton([EndpointDataSource], $endpointDataSource))
         
        $svc.AddRouting()
        
        $svc.AddDirectoryBrowser()
        
        $svc.AddMvc([Action[MvcOptions]]{ param($options) $options.EnableEndpointRouting = $true}).
             SetCompatibilityVersion([CompatibilityVersion]::Version_2_2).
             AddControllersAsServices()

        [SwaggerGenServiceCollectionExtensions]::AddSwaggerGen($svc, [Action[SwaggerGenOptions]][PSDelegate]{
            param([SwaggerGenOptions]$c)
            [SwaggerGenOptionsExtensions]::SwaggerDoc($c, 'v1', [Info]@{ Title = 'My API'; Version = 'v1' })
        })
    }

    [void] Configure([IApplicationBuilder]$app, [IHostingEnvironment]$env) {
        Write-Host "Configure Stella" -Foreground Magenta
        [Stella]::WriteAvailableMethods('ApplicationBuilder', $app)
        [Stella]::WriteAvailableMethods('HostingEnvironment', $env)
        
        $dlgStella = $this
        $appLifetime = $app.ApplicationServices.GetRequiredService([IApplicationLifetime])
        $appLifetime.ApplicationStarted.Register( [action][psdelegate]{ $dlgStella.OnStarted() })
        $appLifetime.ApplicationStopping.Register([action][psdelegate]{ $dlgStella.OnStopping() })
        $appLifetime.ApplicationStopped.Register( [action][psdelegate]{ $dlgStella.OnStopped() })

        $this.logger.LogInformation("Environment: {0}" -f  $this.environment.EnvironmentName, $null)
        if ($this.environment.IsDevelopment) {
            $app.UseDeveloperExceptionPage()
            $this.logger.LogTrace("Logger Test : Trace", $null)
            $this.logger.LogDebug("Logger Test : Debug", $null)
            $this.logger.LogInformation("Logger Test : Information", $null)
            
        }
        else {
            # $app.UseExceptionHandler('/Home/Error')
        }
        
        $app.UseDefaultFiles()
        $app.UseStaticFiles()
        if($Script:UseFileServer) {
            $app.UseFileServer($true)
        }
        if($Script:UseDirectoryBrowser) {
            $app.UseDirectoryBrowser()
            # $app.UseDirectoryBrowser([DirectoryBrowserOptions]@{
            #     FileProvider = [PhysicalFileProvider]::new("C:\Users\Joel\Projects\Modules\TouchPS\Source\Web\")
            #     RequestPath = "/web"
            # })
        }
        
        $app.UseMvc()
        
        [SwaggerBuilderExtensions]::UseSwagger($app)
        [SwaggerUIBuilderExtensions]::UseSwaggerUI($app, [Action[SwaggerUIOptions]][PSDelegate]{
            param([SwaggerUIOptions]$c)
            [SwaggerUIOptionsExtensions]::SwaggerEndpoint($c, '/swagger/v1/swagger.json', 'My API V1')
        })
        
        $app.psbase.Use([Func`2[[RequestDelegate], [RequestDelegate]]]{
            param([RequestDelegate]$next)
            return [RequestDelegate][PSDelegate]{
                param([HttpContext] $httpContext)
                [Console]::WriteLine("1st")
                $httpContext.Response.WriteAsync('First', [CancellationToken]::None).GetAwaiter()
                return [Task]([RequestDelegate]$next).Invoke([HttpContext]$httpContext)
            }
            
        })
        
        [UseExtensions]::Use(
            $app, 
            [Func[[HttpContext], [Func[Task]], [Task]]][PSDelegate]{
                param([HttpContext] $httpContext, [Func[Task]] $next)
                [Console]::WriteLine("2nd")
                $httpContext.Response.WriteAsync('Secund', [CancellationToken]::None).GetAwaiter()
                return [Task]$next.Invoke()
            }
        )
        
        $app.Run([RequestDelegate][PSDelegate]{ 
            param([HttpContext] $httpContext)
            [Console]::WriteLine("Last")
            return [Task]$httpContext.Response.WriteAsync('Last', [CancellationToken]::None)
        })
    }
          
    hidden static WriteAvailableMethods([string]$name, [object]$object) {
        
        $methods = @( $object.psobject.Members |  Where-Object { 
            $_.MemberType -like "*Method*" -and 
            $_.Name -notlike '*_*' -and $_.Name -notin @(
                'GetType', 'GetHashCode', 'Equals', 'ToString', 'Dispose', 
                'Contains', 'Clear', 'CopyTo', 'Remove', 'GetEnumerator', 'IndexOf', 'Insert', 'RemoveAt'
            )
        })
        if ( $methods.count -gt 0 ) {
            "$name Methods :    "           | Write-Host -Foreground Cyan -NoNewLine
            $methods.Name -join ", "     | Write-Host
        }

        $properties = @( $object.psobject.Members |  Where-Object { 
            $_.MemberType -like "*Property*" -and $_.MemberType -ne 'ParameterizedProperty' -and
            $_.Name -notlike '*_*' -and $_.Name -notin @(
                'Count', 'IsReadOnly', 'Item'
            ) 
        } )
        if ( $properties.count -gt 0 ) {
            "$name Properties : "        | Write-Host  -Foreground Cyan -NoNewLine
            $properties.Name -join ", "  | Write-Host
        }
        " " | Write-Host
    }  
    
    hidden [void] OnStarted() {
        Write-Host 'Stella Started' -Foreground Magenta
        # Perform post-startup activities here
    }
    
    hidden [void] OnStopping() {
        Write-Host 'Stella Stopping' -Foreground Magenta
        # Perform on-stopping activities here
        
    }
    
    hidden [void] OnStopped() {
        Write-Host 'Stella Stopped' -Foreground Magenta
        # Perform post-stopped activities here
    }
    
}

function Start-Stella {
    [CmdletBinding()]
    param(
        [string[]]$Uri = 'http://localhost:8080',
        [string]$Environment = 'Development',
        # ASP.NET likes to know a root folder to look in for views, etc. By default uses "WebSite" in the module
        [string]$ContentRoot = $(Join-Path $PSScriptRoot WebSite),
        # Static files may be served from here (defaults to $ContentRoot\wwwroot)
        [string]$WebRoot,
        [switch]$DirectoryBrowser,
        [type] $StartupType = ('Stella' -as [type]),
        [switch]$Invoke
    )

    [Environment]::SetEnvironmentVariable("ASPNETCORE_ENVIRONMENT", $Environment, [EnvironmentVariableTarget]::Process)
    
    $builder = [WebHostBuilder]::new()
    
    [WebHostBuilderExtensions]::UseStartup($builder, $StartupType) > $null
    
    $builder.UseSetting('ApplicationName', 'Stella') > $null
    $builder.UseSetting('DetailedErrors', 'true') > $null
    $builder.UseSetting('PreventHostingStartup', 'false') > $null
    [HostingAbstractionsWebHostBuilderExtensions]::CaptureStartupErrors($builder, $false)  > $null
    [HostingAbstractionsWebHostBuilderExtensions]::SuppressStatusMessages($builder, $false)  > $null
    
    [HostingAbstractionsWebHostBuilderExtensions]::UseUrls($builder, $Uri) > $null
    [HostingAbstractionsWebHostBuilderExtensions]::UseContentRoot($builder, $ContentRoot) > $null
    
    if($WebRoot) {
        $Script:UseFileServer = $true
        [HostingAbstractionsWebHostBuilderExtensions]::UseWebRoot($builder, $WebRoot) > $null
    } else {
        $Script:UseFileServer = Test-Path (Join-Path $ContentRoot wwwroot)
    }
    if($DirectoryBrowser) {
        $Script:UseDirectoryBrowser = $true
    }
       
    # https://docs.microsoft.com/en-us/aspnet/core/fundamentals/servers/kestrel
    [WebHostBuilderKestrelExtensions]::UseKestrel($builder) > $null
    [WebHostBuilderKestrelExtensions]::ConfigureKestrel($builder, [Action[WebHostBuilderContext,KestrelServerOptions]]{
        param($context, $options)
        $options.Limits.MaxConcurrentConnections = 100
        $options.Limits.MaxConcurrentUpgradedConnections = 100
        $options.Limits.MaxRequestBodySize = 10 * 1024
        $options.Limits.MinRequestBodyDataRate = [MinDataRate]::new(100, "00:00:10")
        $options.Limits.MinResponseDataRate = [MinDataRate]::new(100, "00:00:10")
        # $options.Listen([IPAddress]::Any, 8080)
        # $options.Listen([IPAddress]::Any, 8081,
        # { param($listenOptions)
        #     $listenOptions.UseHttps("testCert.pfx", "testPassword");
        # })
    }) > $null

    # We need to put this runspace into each thread, like:
    # [System.Management.Automation.Runspaces.Runspace]::DefaultRunspace = Get-Runspace

    $webhost = $builder.build()

    $webHost | Add-Member -MemberType 'ScriptProperty' -Name 'Name' -Value { return $this.Options.ApplicationName }
    $webHost | Add-Member -MemberType 'ScriptProperty' -Name 'Environment' -Value { return $this.Options.Environment }
    $webHost | Add-Member -MemberType 'ScriptProperty' -Name 'Addresses' -Value { return @($this.Server.Features.Value.Addresses) }
    $webHost | Add-Member -MemberType 'ScriptProperty' -Name 'Stopped' -Value { return $this.GetType().GetField('_stopped', [BindingFlags]'NonPublic, Instance').GetValue($this) }
    $webHost | Add-Member -MemberType 'ScriptProperty' -Name 'WebRoot' -Value { return $this.Options.WebRoot }
    $webHost | Add-Member -MemberType 'ScriptProperty' -Name 'ContentRoot' -Value { return $this.Options.ContentRootPath }
    
    $webHost | Add-Member -MemberType 'ScriptProperty' -Name 'Startup' -Value  { $this.gettype().GetField('_startup', [BindingFlags]'NonPublic, Instance').GetValue($this) }
    $webHost | Add-Member -MemberType 'ScriptProperty' -Name 'Config' -Value { $this.gettype().GetField('_config', [BindingFlags]'NonPublic, Instance').GetValue($this) }
    $webHost | Add-Member -MemberType 'ScriptProperty' -Name 'Options' -Value  { $this.gettype().GetField('_options', [BindingFlags]'NonPublic, Instance').GetValue($this) }
    $webHost | Add-Member -MemberType 'ScriptProperty' -Name 'Logger' -Value  { $this.gettype().GetField('_logger', [BindingFlags]'NonPublic, Instance').GetValue($this) }
    $webHost | Add-Member -MemberType 'ScriptProperty' -Name 'Server' -Value  { $this.gettype().GetProperty('Server', [BindingFlags]'NonPublic, Instance').GetValue($this) }
    $webHost | Add-Member -MemberType 'ScriptProperty' -Name 'ServicesException' -Value  { $this.gettype().GetField('_applicationServicesException', [BindingFlags]'NonPublic, Instance').GetValue($this) }
    $webHost | Add-Member -MemberType 'ScriptProperty' -Name 'ServiceCollection' -Value  { $this.gettype().GetField('_applicationServiceCollection', [BindingFlags]'NonPublic, Instance').GetValue($this) }
   
    $defaultPropertyName = 'Name', 'Environment', 'Addresses', 'Stopped', 'WebRoot', 'ContentRoot'
    $defaultPropertySet = [PSMemberInfo[]] [PSPropertySet]::new('DefaultDisplayPropertySet', [string[]]$defaultPropertyName)
    $webHost | Add-Member -MemberType 'MemberSet' -Name 'PSStandardMembers' -Value $defaultPropertySet

    if ($Invoke) {
        $webHost.StartAsync([System.Threading.CancellationToken]::new($false)) > $null
        $webHost
    }
    else {
        [WebHostExtensions]::Run($webhost)
    }
}

function Invoke-Stella {
    [CmdletBinding()]
    param(
        [string[]]$Uri,
        [string]$Environment,
        [string]$ContentRoot,
        [string]$WebRoot,
        [switch]$DirectoryBrowser
    )
    Start-Stella @PSBoundParameters -Invoke
}

function Stop-Stella {
    param($StellaHost)
    $StellaHost.StopAsync([System.Threading.CancellationToken]::new($false)).GetAwaiter() > $null
}
