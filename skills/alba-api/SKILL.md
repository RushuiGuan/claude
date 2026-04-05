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

### `Requests/TestRequest.cs` (sample request with validation)

```csharp
using Albatross.Input;
using FluentValidation;

namespace {{RootNamespace}}.Requests;

public class TestRequestValidator : AbstractValidator<TestRequest>, ICached<TestRequestValidator> {
	public TestRequestValidator() {
		RuleFor(x => x.Name).NotEmpty().MaximumLength(256);
	}
}

public record class TestRequest : IRequest<TestRequest> {
	public required string Name { get; init; }

	public TestRequest Sanitize() {
		return this with { Name = Name.Trim() };
	}

	public static AbstractValidator<TestRequest> Validator => ICached<TestRequestValidator>.Instance;
}
```

### `Controllers/TestController.cs` (starter controller with GET and POST)

```csharp
using Albatross.Hosting;
using Albatross.Input;
using Microsoft.AspNetCore.Mvc;
using {{RootNamespace}}.Requests;

namespace {{RootNamespace}}.Controllers;

[ApiController]
[Route("api/[controller]")]
public class TestController : ControllerBase {
	[HttpGet]
	public string Get() => "ok";

	[HttpPost]
	public async Task<ActionResult> Post([FromBody] TestRequest request, CancellationToken cancellationToken) {
		if (request.Validate(out var sanitized).HasProblem(out var problem)) {
			return BadRequest(problem);
		}
		// use sanitized here
		return Ok();
	}
}
```

These are starter files to demonstrate the patterns. The user should rename or replace them with real domain types.

---

## Controller coding rules

Apply these rules whenever scaffolding or adding any controller action:

**Never return a database entity from an endpoint.** Always return a DTO. If no DTO exists for the entity, create one before writing the controller action.

Where to place the DTO:
- Look for a sibling project named `{AppName}.Core` (e.g. `Sample.Core` for `Sample.WebApi`)
- If a `Dtos/` folder exists inside that project, place the DTO there
- If the project exists but has no `Dtos/` folder, place the DTO in its root
- Name the DTO after the entity with a `Dto` suffix (e.g. `Company` → `CompanyDto`)

```csharp
// Sample.Core/Dtos/CompanyDto.cs
namespace Sample.Core.Dtos;

public record class CompanyDto {
    public required int Id { get; init; }
    public required string Name { get; init; }
}
```

The entity is responsible for creating its own DTO. Add a method on the entity class that returns the DTO:

```csharp
// On the entity
public CompanyDto CreateDto() => new CompanyDto { Id = Id, Name = Name };
```

The controller calls `CreateDto()` — it does not construct the DTO itself:

```csharp
// In the controller
var company = await companyRepository.GetById(id, cancellationToken);
return company.CreateDto();
```


**Always add `CancellationToken cancellationToken` as the last parameter on every async action.** ASP.NET Core binds it automatically from the request — no attribute needed. Do not add it to synchronous methods. If a method needs `CancellationToken`, it must also be `async Task<T>`.

```csharp
// correct
[HttpGet("{id}")]
public async Task<MyDto> GetById(Guid id, CancellationToken cancellationToken) { ... }

[HttpPost]
public async Task<ActionResult<MyDto>> Create(MyDto dto, CancellationToken cancellationToken) { ... }

// wrong — missing cancellationToken
[HttpGet("{id}")]
public async Task<MyDto> GetById(Guid id) { ... }
```

Pass `cancellationToken` through to every downstream async call (repository, service, `SaveChangesAsync`, etc.) so the entire call chain respects request cancellation.

---

## HTTP POST request validation (request validation pattern)

Every POST action must validate and sanitize its request body using `Albatross.Input` before doing any work. The pattern has two parts:

### 1. Request class (in the Core/shared project)

Implement `IRequest<T>` on a `record class`. The request is responsible for its own sanitization and exposes a cached validator. The validator and the request DTO always live in the **same file**, named after the request DTO class (e.g. `CreateCompanyRequest.cs`):

```csharp
using Albatross.Input;
using FluentValidation;

public class MyRequestValidator : AbstractValidator<MyRequest>, ICached<MyRequestValidator> {
    public MyRequestValidator() {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(256);
        // add rules as needed
    }
}

public record class MyRequest : IRequest<MyRequest> {
    public required string Name { get; init; }

    public MyRequest Sanitize() {
        return this with { Name = Name.Trim() };
        // apply any normalization/trimming here
    }

    public static AbstractValidator<MyRequest> Validator => ICached<MyRequestValidator>.Instance;
}
```

### 2. Controller POST action

Call `.Validate(out var sanitized).HasProblem(out var problem)` and return `BadRequest(problem)` if validation fails. Use the sanitized value for all further work.

`HasProblem` is an extension method in `Albatross.Hosting` — always include `using Albatross.Hosting;` in the controller file:

```csharp
using Albatross.Hosting;   // required for HasProblem extension method
using Albatross.Input;
using Microsoft.AspNetCore.Mvc;

[HttpPost]
public async Task<ActionResult> Post([FromBody] MyRequest request, CancellationToken cancellationToken) {
    if (request.Validate(out var sanitized).HasProblem(out var problem)) {
        return BadRequest(problem);
    }
    // use sanitized, not request
    return Ok();
}
```

Never skip validation on POST actions. Never use the original `request` after calling `Validate` — always use `sanitized`.

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

To disable any of these, override the property in `Startup.cs`:

```csharp
public override bool OpenApi => false;
```

## Request logging

The base `Startup` class does **not** include request logging. Use `Serilog.AspNetCore`'s `UseSerilogRequestLogging()` middleware by overriding `Configure` in your `Startup`:

```csharp
public class Startup : Albatross.Hosting.Startup {
	public Startup(IConfiguration configuration) : base(configuration) { }

	public override void Configure(IApplicationBuilder app, ProgramSetting programSetting, EnvironmentSetting environmentSetting, ILogger<Startup> logger) {
		app.UseSerilogRequestLogging();
		base.Configure(app, programSetting, environmentSetting, logger);
	}
}
```

Call `UseSerilogRequestLogging()` **before** `base.Configure(...)` so it wraps the full request pipeline. Serilog writes one structured log entry per request including method, path, status code, and elapsed time.

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
- [ ] No endpoint returns a database entity — all return DTOs from the Core project
