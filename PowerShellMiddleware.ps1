if (!(Test-Path "$PSScriptRoot\bin\PowerShellMiddleware.dll")) {
    Write-Host "Adding Middleware"
    Add-Type "
    namespace PoshCode {
        using System.Management.Automation.Runspaces;
        using System.Threading.Tasks;
        using Microsoft.AspNetCore.Builder;
        using Microsoft.AspNetCore.Http;

        public class NewRunspaceMiddleware
        {
            private readonly RequestDelegate _next;

            public NewRunspaceMiddleware(RequestDelegate next)
            {
                _next = next;
            }

            // IMyScopedService is injected into Invoke
            public async Task Invoke(HttpContext httpContext)
            {
                if (null == Runspace.DefaultRunspace) {
                    System.Console.WriteLine(`"Create Runspace`");
                    Runspace.DefaultRunspace = RunspaceFactory.CreateRunspace();
                } else {
                    System.Console.WriteLine(`"Runspace Exists`");
                }
                await _next(httpContext);
            }
        }

        public static class PowerShellMiddlewareExtensions
        {
            public static IApplicationBuilder UseNewRunspace(this IApplicationBuilder builder)
            {
                return builder.UseMiddleware<NewRunspaceMiddleware>();
            }
        }
    }
    " -OutputType Library -OutputAssembly "$PsScriptRoot\bin\PowerShellMiddleware.dll" -ReferencedAssemblies netstandard,
        System.Console,
        System.Threading.Tasks,
        System.Management.Automation,
        "$PsScriptRoot\bin\Microsoft.AspNetCore.2.2.0\lib\netstandard2.0\Microsoft.AspNetCore.dll",
        "$PsScriptRoot\bin\Microsoft.AspNetCore.Http.Abstractions.2.2.0\lib\netstandard2.0\Microsoft.AspNetCore.Http.Abstractions.dll"
}