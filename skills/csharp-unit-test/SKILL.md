---
name: csharp-unit-test
description: >
  How to write xUnit v3 unit tests in this codebase following the established conventions:
  one file per method under test, named ClassName.MethodName.cs; test methods named after
  scenarios; Theory + InlineData preferred over separate Fact methods whenever multiple
  input cases exist. Use this skill whenever the user asks to write, add, or scaffold unit
  tests, test a method, cover a class, or add test cases — even if they just say "write
  tests for X" or "add coverage for Y". Trigger on: "write a test", "add tests", "test this
  method", "add unit tests", "cover this with tests", or anything involving xunit test creation.
---

# C# Unit Test Conventions

## File layout

Each **method under test** gets its own file. Both the file name and the class name use underscores:

```
ClassName_MethodName.cs
```

```csharp
public class ClassName_MethodName { ... }
```

Use the **simple class name** — not the namespace-qualified name. Place the file in the
appropriate test project alongside the other test files.

---

## Test method naming

Name each test method after the **scenario** it covers, not the method it calls. The goal
is that someone reading the test list immediately understands what behavior is verified.

Good scenario names:
- `ValidName`
- `InvalidName_ThrowsArgumentException`
- `DuplicateName_ThrowsArgumentException`
- `ActiveAccount_ReturnsToken`
- `InactiveAccount_ThrowsInvalidOperation`

Avoid generic names like `Test1`, `HappyPath`, or `TestConstructorValid`.

---

## Theory vs Fact

Prefer `[Theory]` + `[InlineData]` over separate `[Fact]` methods whenever the same
assertion logic applies across multiple inputs. This keeps the test count low and the
intent visible at a glance.

Use `[Fact]` only when the test is inherently single-case (e.g., a side-effect that
can't be parameterized, or a scenario with no varying input).

```csharp
// Preferred: one Theory covering multiple valid inputs
[Theory]
[InlineData("alice")]
[InlineData("bob-smith")]
[InlineData("x")]
public void ValidName(string name) {
    var account = new Account(tenantId, name);
    Assert.Equal(name, account.Name);
}

// Preferred: one Theory covering multiple invalid inputs
[Theory]
[InlineData("")]
[InlineData(" ")]
[InlineData("alice@bad")]
[InlineData("a-")]
public void InvalidName_ThrowsArgumentException(string name) {
    Assert.Throws<ArgumentException>(() => new Account(tenantId, name));
}
```

---

## Class structure

```csharp
using Xunit;
using Anchor.Models;  // adjust to the namespace under test

namespace Anchor.Test {
    public class Account_CreateCredential {
        // Use AutoFixture for complex dependencies you don't care about
        private readonly Fixture fixture = new();

        // Put shared setup values here if the same value appears in most tests
        private readonly Guid tenantId = Guid.NewGuid();

        [Theory]
        [InlineData("key1")]
        [InlineData("my-key")]
        public void ValidName(string name) {
            var account = fixture.Create<Account>();
            var credential = account.CreateCredential(name);
            Assert.Equal(name, credential.Name);
        }

        [Theory]
        [InlineData("")]
        [InlineData("-")]
        [InlineData("key@")]
        public void InvalidName_ThrowsArgumentException(string name) {
            var account = fixture.Create<Account>();
            Assert.Throws<ArgumentException>(() => account.CreateCredential(name));
        }

        [Fact]
        public void InactiveAccount_ThrowsInvalidOperationException() {
            var account = fixture.Build<Account>().With(x => x.Active, false).Create();
            Assert.Throws<InvalidOperationException>(() => account.CreateCredential("key"));
        }
    }
}
```

---

## Dependencies and test data

- Use **AutoFixture** (`new Fixture()`) to create objects you don't want to set up by hand.
- Use `fixture.Build<T>().With(x => x.Prop, value).Create()` to control specific properties.
- For simple primitive inputs, inline them directly in `[InlineData]` — no fixture needed.
- For multi-line string constants (e.g. PEM keys), use verbatim string literals (`@"..."`) rather than concatenation with `\n`.

---

## Testing services with Moq

Services depend on `IAnchorRepository` (and other interfaces) to fetch data. Because you
can't run a real database in a unit test, mock the repository with **Moq** so you control
exactly what data the service sees.

### Setup pattern

```csharp
using Moq;
using Xunit;
using Anchor.Models;
using Anchor.Repositories;
using Anchor.Services;

namespace Anchor.Test {
    public class AccountService_CreateServiceAccount {
        private readonly Mock<IAnchorRepository> repositoryMock = new();
        private readonly Mock<ISettingService> settingServiceMock = new();
        private readonly TimeProvider timeProvider = TimeProvider.System;
        private readonly IAccountService sut;  // system under test

        public AccountService_CreateServiceAccount() {
            sut = new AccountService(
                repositoryMock.Object,
                settingServiceMock.Object,
                timeProvider);
        }

        [Fact]
        public async Task ValidRequest_CreatesAccount() {
            var tenant = fixture.Create<Tenant>();
            repositoryMock
                .Setup(r => r.GetTenant("my-tenant", It.IsAny<CancellationToken>()))
                .ReturnsAsync(tenant);

            var request = new CreateServiceAccountRequest { AccountName = "svc1", ... };
            var account = await sut.CreateServiceAccount(actorId, "my-tenant", request, CancellationToken.None);

            Assert.Equal("svc1", account.Name);
            Assert.Equal(AccountType.ServicePrincipal, account.Type);
        }
    }
}
```

### Key rules

- Declare `Mock<IRepository>` (and other mocked dependencies) as fields so all test methods share the same mock instance.
- Construct the **service under test** in the constructor (xUnit instantiates the class per test, so state is always fresh).
- Use `Setup(...).ReturnsAsync(...)` to control what the repository returns for a given call.
- Use `repositoryMock.Verify(r => r.SomeMethod(...), Times.Once())` when the test cares that a side-effect method was called.
- Only mock what the specific test scenario needs — unused setups are fine to omit.
- Use `It.IsAny<T>()` for parameters you don't care about; use exact values when the correct routing matters.

---

## Assertions

Use `Xunit.Assert`. Prefer specific assertions over booleans:

| Situation | Use |
|---|---|
| Expected value | `Assert.Equal(expected, actual)` |
| Not null | `Assert.NotNull(result)` |
| Exception thrown | `Assert.Throws<TException>(() => ...)` |
| Async exception | `await Assert.ThrowsAsync<TException>(async () => ...)` |
| Collection contains | `Assert.Contains(item, collection)` |
| Boolean condition | `Assert.True(...)` / `Assert.False(...)` |

`FluentAssertions` is also available if you prefer a more readable chain style
(`result.Should().Be(expected)`), but keep assertions consistent within a file.

---

## Testing internal methods

Some methods are `internal` rather than `public` — they are implementation details that
shouldn't be part of the public interface, but still need direct test coverage. C# supports
this via `InternalsVisibleTo`.

### Step 1 — expose internals to the test project

In the project being tested (e.g. `Anchor`), add an `AssemblyInfo.cs` file if one doesn't
exist, and declare the attribute:

```csharp
// Anchor/AssemblyInfo.cs
using System.Runtime.CompilerServices;
[assembly: InternalsVisibleTo("Anchor.Test")]
```

Check whether the file already exists before creating it. If `InternalsVisibleTo` is
already declared, skip this step.

### Step 2 — instantiate the concrete class, not the interface

Internal methods are not on the interface, so the test must hold a reference to the
**concrete class** directly:

```csharp
public class ProviderAuthService_ValidateCallbackRequest {
    private readonly Mock<IAnchorRepository> repositoryMock = new();
    // ... other mocks ...
    private readonly ProviderAuthService sut;  // concrete type, not IProviderAuthService

    public ProviderAuthService_ValidateCallbackRequest() {
        sut = new ProviderAuthService(
            repositoryMock.Object,
            /* other dependencies */);
    }

    [Fact]
    public async Task ExpiredRequest_ThrowsException() {
        // arrange via repositoryMock ...
        await Assert.ThrowsAsync<InvalidAuthorizationRequestRequestException>(
            () => sut.ValidateCallbackRequest(request, CancellationToken.None));
    }
}
```

The rest of the conventions (one file per method, scenario-named test methods,
`Theory`/`InlineData`, Moq setup) apply exactly as for public methods.

---

## Quick checklist

When adding tests for `SomeClass.SomeMethod`:

1. Create `SomeClass_SomeMethod.cs` in the test project
2. Declare `public class SomeClass_SomeMethod { ... }`
3. If testing a **domain model method**: use AutoFixture to build the object, no mocking needed
4. If testing a **service method**: declare `Mock<IRepository>` fields, construct the service in the constructor, `Setup` only what the scenario needs
5. Write one `[Theory]` for valid-input scenarios, one for invalid/exception scenarios
6. Name each test method after the scenario, not the method under test
7. Add `[InlineData]` cases for each interesting boundary value
8. Use `[Fact]` only if the scenario genuinely can't be parameterized
