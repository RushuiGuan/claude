---
name: alba-input
description: >
  How to use the Albatross.Input library to apply the Request Validation Pattern and the
  Validated String Type pattern in C#. Use this skill whenever the user is working with request
  validation, creating a request class, implementing IRequest&lt;T&gt;, IValidateString&lt;T&gt;, ICached&lt;T&gt;,
  or Optional&lt;T&gt; in an Albatross-based project. Trigger on requests like "add a new request",
  "validate this input", "create a request class", "add validation to this endpoint",
  "I need a validated string type", or anything involving input sanitization or validation
  patterns. Always use this skill before writing any request or string-validator classes.
---

# Albatross.Input Patterns

`Albatross.Input` introduces **validation patterns** — it does not reimplement validation logic.
FluentValidation is used deliberately for the actual rules. The library's job is to define
how validation is structured and when it runs.

## Installation

```bash
dotnet add package Albatross.Input --prerelease
```

Pre-release versions are fine.

---

## Pattern 1: Request Validation Pattern

Use this pattern for any incoming request object — HTTP POST/PUT bodies, command payloads, or
anything that needs to be sanitized and validated before use.

### The contract

`IRequest<T>` requires two things from the implementing class:

```csharp
public interface IRequest<T> where T : class, IRequest<T> {
    T Sanitize();
    static abstract AbstractValidator<T> Validator { get; }
}
```

- `Sanitize()` — normalizes the input (trim strings, canonicalize values) and returns a new
  instance. Sanitization runs **before** validation so rules run on clean data.
- `Validator` — a static property returning the FluentValidation validator for this type.

### ICached<T> — singleton validator

Validators are stateless and expensive to allocate. `ICached<T>` provides a free singleton:

```csharp
public interface ICached<out T> where T : ICached<T>, new() {
    public static T Instance { get; } = new();
}
```

Implement it on the validator class, then reference `ICached<MyValidator>.Instance` from the
request's `Validator` property. This avoids creating a new validator on every request.

### Full example

The validator and the request class always live in the **same file**, named after the request:

```csharp
using Albatross.Input;
using FluentValidation;

public class CreateOrderRequestValidator : AbstractValidator<CreateOrderRequest>,
    ICached<CreateOrderRequestValidator> {
    public CreateOrderRequestValidator() {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(256);
        RuleFor(x => x.Quantity).GreaterThan(0);
    }
}

public record class CreateOrderRequest : IRequest<CreateOrderRequest> {
    public required string Name { get; init; }
    public required int Quantity { get; init; }

    public CreateOrderRequest Sanitize() {
        return this with { Name = Name.Trim() };
    }

    public static AbstractValidator<CreateOrderRequest> Validator
        => ICached<CreateOrderRequestValidator>.Instance;
}
```

### Validating

The `Validate` extension method sanitizes and validates in one call:

```csharp
var result = request.Validate(out var sanitized);
```

`sanitized` is the sanitized copy. Always use `sanitized` downstream — never use the original
`request` after calling `Validate`.

In ASP.NET Core controllers, `HasProblem` from `Albatross.Hosting` converts the result into an
RFC 7807 problem response:

```csharp
using Albatross.Hosting;   // for HasProblem

if (request.Validate(out var sanitized).HasProblem(out var problem)) {
    return BadRequest(problem);
}
// use sanitized from here
```

`HasProblem` is defined in `Albatross.Hosting`, not `Albatross.Input` — it is the bridge
between the validation result and ASP.NET Core's `ActionResult` model.

---

## Pattern 2: Validated String Type

Use this pattern when a string input has a well-defined shape — a resource name, a tag, a
short code — and you want that shape enforced at the type level rather than scattered across
FluentValidation rules.

The pattern wraps a raw string in a strongly-typed value object. The validation is intentionally
shallow: null/empty checks, length bounds, and at most a simple regex. Business logic does not
belong here.

For non-string primitives (`int`, `Guid`, `DateTime`, etc.), this pattern is not needed —
parsing is sufficient validation.

### The contract

```csharp
public interface IValidateString<T> : IParsable<T> where T : IValidateString<T> {
    string? Value { get; }
    static abstract ValidationResult Validate(string? text);
}
```

- `Value` — the wrapped string.
- `Validate(string?)` — static method returning a `ValidationResult`. No business logic.
- `Parse` / `TryParse` — from `IParsable<T>`, for standard .NET parsing idioms and model binding.

### Composing with Pattern 1

The static `Validate` method can delegate to an `ICached<T>` FluentValidation validator, keeping
the actual rules in one place and reusable by request validators:

```csharp
public class ResourceNameValidator : AbstractValidator<string?>,
    ICached<ResourceNameValidator> {
    public ResourceNameValidator() {
        RuleFor(x => x).NotEmpty().MaximumLength(256);
    }
}
```

Then `Validate` simply delegates:

```csharp
public static ValidationResult Validate(string? text) =>
    ICached<ResourceNameValidator>.Instance.Validate(text);
```

This means the same `ResourceNameValidator` can be referenced directly in a request validator
using `SetValidator`, eliminating duplicated rules:

```csharp
public class CreateOrderRequestValidator : AbstractValidator<CreateOrderRequest>,
    ICached<CreateOrderRequestValidator> {
    public CreateOrderRequestValidator() {
        // reuse the cached string validator instead of repeating NotEmpty/MaximumLength
        RuleFor(x => x.Name).SetValidator(ICached<ResourceNameValidator>.Instance);
        RuleFor(x => x.Quantity).GreaterThan(0);
    }
}
```

When you introduce a validated string type for a field that already exists in one or more
request validators, go back and update those validators to use `SetValidator` with the cached
instance rather than keeping their own inline rules for the same field.

### Full example

```csharp
using FluentValidation;
using FluentValidation.Results;
using System.Diagnostics.CodeAnalysis;
using Albatross.Input;

public class ResourceNameValidator : AbstractValidator<string?>,
    ICached<ResourceNameValidator> {
    public ResourceNameValidator() {
        RuleFor(x => x).NotEmpty().MaximumLength(256);
    }
}

public sealed class ResourceName : IValidateString<ResourceName> {
    public string Value { get; }

    public ResourceName(string value) {
        this.Value = value;
    }

    public static ResourceName Parse(string input, IFormatProvider? provider) {
        var errors = Validate(input);
        if (!errors.IsValid) {
            throw new ValidationException(errors.Errors);
        }
        return new ResourceName(input);
    }

    public static bool TryParse(string? input, IFormatProvider? provider,
        [MaybeNullWhen(false)] out ResourceName result) {
        var validationResult = Validate(input);
        if (validationResult.IsValid) {
            result = new ResourceName(input!);
            return true;
        } else {
            result = null;
            return false;
        }
    }

    public static ValidationResult Validate(string? text) =>
        ICached<ResourceNameValidator>.Instance.Validate(text);
}
```
