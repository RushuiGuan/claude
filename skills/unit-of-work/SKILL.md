---
name: unit-of-work
description: >
  How to implement the Unit of Work pattern in ASP.NET Core Web API using Albatross.EFCore,
  Albatross.Hosting.EFCore, Albatross.Input, and Albatross.Hosting together. The controller
  defines the transaction boundary; services own business logic; persistence is committed once
  per request via SaveAndReturn. Use this skill whenever the user is adding or modifying a
  controller action that writes to the database, wiring up a service to a controller, handling
  SaveResults, or working with the full request-to-response pipeline in an Albatross-based
  Web API project. Trigger on: "add a controller action", "add a POST/PUT/DELETE endpoint",
  "wire up the service in the controller", "save to database from the controller", "handle
  save errors in the controller", or anything that combines controllers, services, and persistence.
---

# Albatross Unit of Work Pattern

The unit of work spans a single HTTP request. The controller action is the application boundary:
it validates input, invokes services, and commits exactly once. Services and repositories never
commit — that responsibility belongs exclusively to the controller.

---

## Architecture

```
HTTP Request
     ↓
 Controller action
   • validates & sanitizes request (Albatross.Input)
   • calls service(s) for domain logic
   • calls repository.SaveAndReturn(...)  ← single commit
   • returns DTO
     ↓
   Service
   • performs domain logic
   • calls repository.Add / .Delete / query methods
   • returns entity — never a DTO
   • never calls SaveChanges
     ↓
  Repository
   • reads and writes via IDbSession
```

---

## 1. Service

Services own business logic. They depend on repository interfaces, return **entities**, and
**never call `SaveChangesAsync`**.

```csharp
public interface ICompanyService {
    Task<Company> Create(string name, CancellationToken cancellationToken);
    Task<Company> Update(int id, string name, CancellationToken cancellationToken);
    Task Delete(int id, CancellationToken cancellationToken);
}

public class CompanyService : ICompanyService {
    readonly ICompanyRepository companyRepository;

    public CompanyService(ICompanyRepository companyRepository) {
        this.companyRepository = companyRepository;
    }

    public Task<Company> Create(string name, CancellationToken cancellationToken) {
        var company = new Company { Name = name };
        companyRepository.Add(company);
        return Task.FromResult(company);
        // No SaveChangesAsync — caller is responsible
    }

    public async Task<Company> Update(int id, string name, CancellationToken cancellationToken) {
        var company = await companyRepository.GetById(id, cancellationToken); // throws NotFoundException if missing
        company.Name = name;
        return company;
        // EF change tracking picks up the mutation; no explicit SaveChanges needed here
    }

    public async Task Delete(int id, CancellationToken cancellationToken) {
        var company = await companyRepository.GetById(id, cancellationToken);
        companyRepository.Delete(company);
        // No SaveChangesAsync
    }
}
```

**Rules:**
- Services **never depend on `IDbSession`** — only on repository interfaces.
- Services **never call `SaveChangesAsync`**.
- Services **return entities**, not DTOs — transformation happens in the controller.
- Services **never pre-check uniqueness** — let the database enforce it. `SaveResults` will
  report `NameConflict` if a unique constraint is violated.

---

## 2. DTO

The entity is responsible for constructing its own DTO. Define a `CreateDto()` method directly
on the entity. Place the DTO class in the Core/shared project under a `Dtos/` folder (or root
if no `Dtos/` folder exists). Name it after the entity with a `Dto` suffix.

```csharp
// Sample.Core/Dtos/CompanyDto.cs
public record class CompanyDto {
    public required int Id { get; init; }
    public required string Name { get; init; }
}

// On the entity
public CompanyDto CreateDto() => new CompanyDto { Id = Id, Name = Name };
```

The controller calls `entity.CreateDto()` — it never constructs the DTO itself.

---

## 3. Controller

The controller:
1. Validates and sanitizes the incoming request (`Albatross.Input`)
2. Calls service methods
3. Converts the returned entity to a DTO via `CreateDto()`
4. Commits once via `repository.SaveAndReturn(...)` (from `Albatross.Hosting.EFCore`)

```csharp
using Albatross.Hosting;           // HasProblem extension method
using Albatross.Hosting.EFCore;    // SaveAndReturn / HandleSaveResult
using Albatross.Input;             // Validate extension method
using Microsoft.AspNetCore.Mvc;
using Sample.Core.Dtos;
using Sample.Core.Requests;

[Route("api/[controller]")]
[ApiController]
public class CompanyController : ControllerBase {
    readonly ICompanyService companyService;
    readonly ICompanyRepository companyRepository;

    public CompanyController(ICompanyService companyService, ICompanyRepository companyRepository) {
        this.companyService = companyService;
        this.companyRepository = companyRepository;
    }

    // GET — no saving; query directly and return DTO
    [HttpGet]
    public async Task<List<CompanyDto>> GetAll(CancellationToken cancellationToken) {
        var companies = await companyRepository.GetAll(cancellationToken);
        return companies.Select(x => x.CreateDto()).ToList();
    }

    [HttpGet("{id}")]
    public async Task<CompanyDto> GetById(int id, CancellationToken cancellationToken) {
        var company = await companyRepository.GetById(id, cancellationToken); // throws NotFoundException → 404
        return company.CreateDto();
    }

    // POST — validate, create via service, return DTO
    [HttpPost]
    public async Task<ActionResult<CompanyDto>> Create([FromBody] CreateCompanyRequest request, CancellationToken cancellationToken) {
        if (request.Validate(out var sanitized).HasProblem(out var problem)) {
            return BadRequest(problem);
        }
        return await companyRepository.SaveAndReturn(async ct => {
            var company = await companyService.Create(sanitized.Name, ct);
            return company.CreateDto();
        }, cancellationToken);
    }

    // PUT — validate, update via service, return DTO
    [HttpPut("{id}")]
    public async Task<ActionResult<CompanyDto>> Update(int id, [FromBody] UpdateCompanyRequest request, CancellationToken cancellationToken) {
        if (request.Validate(out var sanitized).HasProblem(out var problem)) {
            return BadRequest(problem);
        }
        return await companyRepository.SaveAndReturn(async ct => {
            var company = await companyService.Update(id, sanitized.Name, ct);
            return company.CreateDto();
        }, cancellationToken);
    }

    // DELETE — no return value
    [HttpDelete("{id}")]
    public async Task<ActionResult> Delete(int id, CancellationToken cancellationToken) {
        return await companyRepository.SaveAndReturn(async ct => {
            await companyService.Delete(id, ct);
        }, cancellationToken);
    }
}
```

**Rules:**
- Inject **both** `ICompanyService` and `ICompanyRepository` — the service is for logic, the
  repository is used as the commit point (`SaveAndReturn`).
- **Never return a database entity** from an endpoint. Always return a DTO.
- **Always add `CancellationToken cancellationToken`** as the last parameter on every async action.
- Validate every POST/PUT body before doing any work. Never use the raw `request` after calling
  `Validate` — always use the `sanitized` copy.

---

## 4. `SaveAndReturn` (Albatross.Hosting.EFCore)

`SaveAndReturn` wraps the work + commit + error handling into one call. Choose the overload
that matches whether the action produces a return value:

| Signature | Use when |
|---|---|
| `SaveAndReturn(Func<CancellationToken, Task<T>>, ct)` → `ActionResult<T>` | Async work that returns a value (create/update) |
| `SaveAndReturn(Func<CancellationToken, Task>, ct)` → `ActionResult` | Async work with no return value (delete) |
| `SaveAndReturn(Func<T>, ct)` → `ActionResult<T>` | Sync work that returns a value |
| `SaveAndReturn(Action, ct)` → `ActionResult` | Sync work with no return value |
| `SaveAndReturn(ct)` → `ActionResult` | Work done before the call; just save |

`SaveAndReturn` internally calls `SaveChangesAsync(throwException: false, ...)` and maps the
result to an HTTP status:

| Condition | HTTP status |
|---|---|
| Success | 200 (with data) or 204 (no data) |
| `NotFoundException` thrown | 404 Not Found |
| `NameConflict` (unique constraint) | 409 Conflict |
| `ForeignKeyConflict` | 422 Unprocessable Entity |
| Other exception | 500 Internal Server Error |

All responses use RFC 7807 `ProblemDetails`.

### Manual approach (when SaveAndReturn doesn't fit)

For complex cases, call `SaveChangesAsync` directly and use `HandleSaveResult`:

```csharp
var company = await companyService.Create(sanitized.Name, cancellationToken);
var results = await companyRepository.SaveChangesAsync(throwException: false, cancellationToken);
return results.HandleSaveResult(company.CreateDto());
// or for void:
return results.HandleSaveResult();
```

---

## 5. Required packages

| Package | Purpose |
|---|---|
| `Albatross.EFCore` | `IRepository`, `SaveResults`, `NotFoundException`, `Repository<T>` |
| `Albatross.Hosting.EFCore` | `SaveAndReturn`, `HandleSaveResult` controller extensions |
| `Albatross.Input` | `IRequest<T>`, `Validate()` extension |
| `Albatross.Hosting` | `HasProblem` extension, global exception handler, `Startup` base class |

---

## Quick Checklist

When adding a write endpoint:

1. Request class implements `IRequest<T>` with validator in the same file — see **alba-input** skill
2. Entity has a `CreateDto()` method; DTO is a `record class` in the Core/shared project
3. Service method: takes primitives, returns entity, no SaveChanges call
4. Controller action:
   - [ ] Validates request: `request.Validate(out var sanitized).HasProblem(out var problem)`
   - [ ] Calls service with `sanitized` values (not raw `request`)
   - [ ] Wraps work in `repository.SaveAndReturn(...)`
   - [ ] Returns `entity.CreateDto()` — never returns the entity itself
   - [ ] Has `CancellationToken cancellationToken` as last parameter
