---
name: alba-api
description: >
  Template and instructions for scaffolding new ASP.NET Core Web API projects using Albatross.Hosting.
  Use this skill whenever the user asks to create a new web API project, create a new API project,
  scaffold a WebAPI app, or update an existing project to use Albatross.Hosting — even if they don't
  say "Albatross" explicitly. Also trigger when the user asks to add a controller, wire up authentication,
  configure startup, or set up the project structure for an ASP.NET Core API that follows the Albatross
  pattern. Always use this skill before writing any project files.
---

# Albatross WebAPI Project Scaffolding

Use this skill to scaffold a complete ASP.NET Core Web API project using `Albatross.Hosting`. Generate all files in one shot.

---

## Step 1: Get the project location

If the user has not specified where to create the project, **ask for the target directory** before generating any files. Do not guess or default to the current working directory without confirming.

---

## Step 2: Resolve the latest package versions

Do **not** hardcode versions in the csproj. Instead, omit the `<ItemGroup>` for `Albatross.Hosting` and `Albatross.Hosting.EFCore` from the initial csproj, then after creating the file run:

```bash
dotnet add <path-to-csproj> package Albatross.Hosting --prerelease
dotnet add <path-to-csproj> package Albatross.Hosting.EFCore --prerelease
```

This resolves the latest version (including pre-release) from all configured sources — NuGet.org and any local package sources — and writes the correct version into the csproj automatically.

---

## Step 3: Determine the project name

Derive the project name from the directory name or from what the user said. Always use PascalCase for each segment, even if the user typed it in lowercase. For example:

- `sample.api` → `Sample.Api`
- `myapp.webapi` → `MyApp.WebApi`
- `crm.api` → `Crm.Api`

The `.csproj` filename, root namespace, and log path in `serilog.json` all use this corrected PascalCase name.

---

## Step 3: Scaffold all files

Generate every file below in one pass. Replace `{{ProjectName}}` with the actual project name and `{{RootNamespace}}` with the root namespace (usually same as project name, dots preserved).

---

### `{{ProjectName}}.csproj`

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">
    <PropertyGroup>
        <OutputType>Exe</OutputType>
        <TargetFramework>net10.0</TargetFramework>
        <Nullable>enable</Nullable>
        <ImplicitUsings>enable</ImplicitUsings>
    </PropertyGroup>
    <ItemGroup>
        <None Include="appsettings*.json">
            <CopyToOutputDirectory>Always</CopyToOutputDirectory>
        </None>
        <None Include="serilog*.json">
            <CopyToOutputDirectory>Always</CopyToOutputDirectory>
        </None>
    </ItemGroup>
</Project>
```

> If the project lives inside the `hosting` solution (i.e. the user is working in this repo), use `<ProjectReference>` instead of `<PackageReference>` for `Albatross.Hosting` and `Albatross.Hosting.EFCore`, pointing to the relative `.csproj` paths. Ask the user if unsure.

> `Albatross.Hosting.EFCore` is always included — it is the integration bridge between `Albatross.EFCore` and `Albatross.Hosting`, providing controller extension methods like `HandleSaveResult`, `SaveAndReturn`, etc.

---

### `Program.cs`

```csharp
namespace {{RootNamespace}};

public class Program {
	public static Task Main(string[] args) {
		Albatross.Logging.Extensions.RemoveLegacySlackSinkOptions();
		return new Albatross.Hosting.Setup(args, AppContext.BaseDirectory)
			.ConfigureWebHost<Startup>()
			.RunAsync();
	}
}
```

---

### `Startup.cs`

```csharp
namespace {{RootNamespace}};

public class Startup : Albatross.Hosting.Startup {
	public Startup(IConfiguration configuration) : base(configuration) { }

	public override void ConfigureServices(IServiceCollection services) {
		base.ConfigureServices(services);
		// Register application services here
	}
}
```

---

### `appsettings.json`

```json
{
  "urls": "http://*:5000",
  "authentication": {
    "useKerberos": false
  }
}
```

> **No Kerberos by default.** If the user asks for Windows/Kerberos authentication, set `"useKerberos": true` and optionally add a `bearerTokens` array for JWT Bearer schemes. See the authentication section below.

---

### `serilog.json`

Copy from `templates/serilog.json` in this skill folder, replacing `{{ProjectName}}` with the actual project name. The result should look like:

```json
{
    "Serilog": {
        "MinimumLevel": {
            "Default": "Information",
            "Override": {
                "System": "Information",
                "Microsoft": "Information"
            }
        },
        "WriteTo": {
            "Console": {
                "Name": "Console",
                "Args": {
                    "outputTemplate": "{Timestamp:yyyy-MM-dd HH:mm:ssz} {MachineName} {TraceIdentifier} {RequestId} {SourceContext} {ThreadId} [{Level:w3}] {Message:lj}{NewLine}{Exception}"
                }
            },
            "File": {
                "Name": "File",
                "Args": {
                    "path": "%LogDirectory%\\{{ProjectName}}\\{{ProjectName}}.log",
                    "outputTemplate": "{Timestamp:yyyy-MM-dd HH:mm:ssz} {MachineName} {TraceIdentifier} {RequestId} {SourceContext} {ThreadId} [{Level:w3}] {Message:lj}{NewLine}{Exception}",
                    "rollingInterval": "Day"
                }
            }
        },
        "Using": [
            "Albatross.Logging"
        ],
        "Enrich": [
            "FromLogContext",
            "WithThreadId",
            "WithMachineName",
            "WithErrorMessage"
        ]
    }
}
```

---

### `Controllers/TestController.cs` (starter controller)

```csharp
using Microsoft.AspNetCore.Mvc;

namespace {{RootNamespace}}.Controllers;

[ApiController]
[Route("api/[controller]")]
public class TestController : ControllerBase {
	[HttpGet]
	public string Get() => "ok";
}
```

This is a minimal health-check style controller. The user can rename or replace it.

---

## Authentication (optional, only when requested)

The base `Startup` class automatically reads `AuthenticationSettings` from `appsettings.json`. No code changes are needed — only config changes.

### JWT Bearer (e.g. Google, Azure AD)

Add to `appsettings.json`:

```json
{
  "authentication": {
    "useKerberos": false,
    "bearerTokens": [
      {
        "provider": "Google",
        "authority": "https://accounts.google.com",
        "audience": ["<your-client-id>"],
        "validateIssuer": true,
        "validateAudience": true,
        "validateLifetime": true
      }
    ]
  }
}
```

### Kerberos / Windows Authentication

Set `"useKerberos": true` in `appsettings.json`. No code changes needed.

### Multiple schemes

Both `useKerberos: true` and `bearerTokens` can coexist. The first entry in `bearerTokens` becomes the default bearer scheme unless `"default"` is set explicitly.

### Protect a controller

```csharp
[Authorize(AuthenticationSchemes = "Google")]
[ApiController]
[Route("api/[controller]")]
public class SecureController : ControllerBase { ... }
```

---

## Key behaviors of `Albatross.Hosting.Startup` (already wired — no code needed)

- **OpenAPI/Swagger** enabled by default (`OpenApi = true`)
- **Global exception handler** — `ArgumentException` → 400, all others → 500, RFC 7807 ProblemDetails
- **Response compression** — Gzip + Brotli
- **Plain text input formatter** — handles `text/plain` request bodies
- **Request logging** — logs every request with username, IP, URL, method to `SourceContext = "usage"`

To disable any of these, override the property in `Startup.cs`:

```csharp
public override bool OpenApi => false;
public override bool LogUsage => false;
```

---

## Using `Albatross.Hosting.EFCore` in controllers

The `Albatross.Hosting.EFCore` package provides extension methods on `SaveResults` to reduce controller boilerplate:

```csharp
// Returns the saved object or a typed error response
return results.HandleSaveResult(data);

// Wraps a repository operation + SaveChanges in one call
return await repository.SaveAndReturn(async ct => {
    var entity = await service.Create(id, name, ct);
}, cancellationToken);
```

See the `alba-efcore` skill for the full data access layer pattern (entities, repositories, services).

---

## Checklist before finishing

- [ ] `dotnet add package Albatross.Hosting --prerelease` and `Albatross.Hosting.EFCore --prerelease` were run to resolve and pin the latest versions
- [ ] `{{ProjectName}}.csproj` has the `ItemGroup` for `appsettings*.json` and `serilog*.json` with `CopyToOutputDirectory Always`
- [ ] `serilog.json` created from template with project name substituted in the log file path
- [ ] `appsettings.json` has `"useKerberos": false` (unless user asked for Kerberos)
- [ ] `Program.cs` calls `RemoveLegacySlackSinkOptions()` before `Setup`
- [ ] `Startup.cs` inherits `Albatross.Hosting.Startup` and passes `IConfiguration` to base
