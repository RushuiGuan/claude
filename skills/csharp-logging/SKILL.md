---
name: csharp-logging
description: >
  Guide for adding logging to C# services in this codebase (Anchor, ASP.NET Core / .NET 10)
  using Microsoft.Extensions.Logging. Covers where to log, which level to use, and what
  context to include. Use this skill whenever the user asks to add logging, add log
  statements, instrument a service, review logging coverage, or says a service "has no
  logging" or "needs logging" — even if they don't say "ILogger" or "Microsoft.Extensions.Logging".
  Trigger on: "add logging to", "this service has no logging", "I forgot to log", "add log
  statements", "instrument this", "where should I log".
---

# Logging Guide

The goal is **diagnostic value, not coverage**. A log line earns its place if it would
help you during a real incident or debugging session. Method entry/exit logs for every
call add noise without adding insight.

---

## Where to log

Three categories of code warrant logging. Everything else generally does not.

### 1. External system calls
Calls to things outside your process — HTTP clients, secret stores, IdP validators,
databases via non-EF paths. These can fail in ways you can't control and can't reproduce
without knowing what was sent.

**Reads vs. writes are treated differently.**

For **read calls** (fetching data):
- Skip the pre-call debug log for routine reads where the result is predictable.
- For **bulk reads** (fetching a collection), log a summary at `LogInformation` *after*
  the call completes — include the count and key filter parameters. This confirms the
  operation ran and gives you the scale without per-item noise.
- Log individual reads at `LogDebug` only when there is genuine uncertainty about what
  will come back (e.g., a lookup that may return null or an unexpected shape).
- Always log on failure.

For **write calls** (mutations, submissions, publishes):
- Log **before** the call with key parameters at `LogDebug` — if the process dies
  mid-call you need to know what was attempted.
- Log success at `LogInformation` — a completed write is a meaningful event worth
  having in the production log.
- Always log on failure.

Do not log credentials, tokens, or secrets — log their identifiers instead.

### 2. Persisted state transitions
Anything that changes durable state: a record consumed, a session created, a token
revoked, an account disabled. These are the events you want a timeline of when
reconstructing what happened.

Log with the entity ID so you can correlate with database records.

### 3. Error paths that swallow exceptions
When a service catches an exception and converts it to a return value (redirect response,
result object, null), the exception detail becomes invisible to the caller. Log it here —
it's the last chance to record what went wrong.

---

## Log levels

| Level | When to use |
|---|---|
| `LogDebug` | Normal flow — reads, pre-call context, routine checks. Useful during development, silent in production. |
| `LogInformation` | Something was **written or changed**: a record created/updated/deleted, a bulk operation completed (with count). |
| `LogWarning` | Expected-but-notable conditions: provider returned an error, session not found, replay attempt detected. |
| `LogError` | Unexpected failures: external call threw, secret retrieval failed, token validation failed. |

The rule of thumb: reads are Debug, writes are Info. A completed write is a meaningful
event in the production timeline; a completed read is routine. A `Warning` means "the
system handled it but something is worth noting." An `Error` means "something broke that
shouldn't have."

---

## Log message wording

Consistent phrasing makes log messages scannable in production and queryable in structured
log systems. A developer who sees `"Token exchange failed"` immediately knows what happened;
`"Failed to exchange token"` is slower to parse. The rules below cover the five message
shapes that appear in practice.

### Phrasing by category

**Before an external call (Debug):** Use the present participle — it conveys an action in
progress and confirms what was attempted if the process dies mid-call.

| Wrong | Right |
|---|---|
| `"Get client secret for provider {Provider}"` | `"Retrieving client secret for provider {Provider}"` |
| `"Token exchange with {Provider}"` | `"Exchanging authorization code with provider {Provider}"` |

**External call failure (Error):** Use the noun form of the operation, then "failed". This
mirrors the wrapped-exception pattern in `alba-error-msg` and keeps the subject front and
center.

| Wrong | Right |
|---|---|
| `"Failed to get client secret for {Provider}"` | `"Client secret retrieval failed for provider {Provider}"` |
| `"Token exchange error for {Provider}"` | `"Token exchange failed for provider {Provider}"` |

**Completed state transition (Information or Debug):** Use past tense, subject first. This
reads as a fact that happened, which is what state-transition logs are.

| Wrong | Right |
|---|---|
| `"Created login session for login {LoginId}"` | `"Login session created for login {LoginId}"` |
| `"Revoking session for login {LoginId}"` | `"Login session revoked for login {LoginId}"` |

**Notable condition (Warning):** Use a noun phrase that names the event. These are security-
or business-relevant conditions that aren't failures but deserve attention.

| Wrong | Right |
|---|---|
| `"Authorization already consumed: {AuthorizationId}"` | `"Replay attempt on provider authorization {AuthorizationId}"` |

**Unexpected/swallowed exception (Error):** Lead with "Unexpected error" so it stands out
immediately from known, handled failures in a log stream.

| Wrong | Right |
|---|---|
| `"Error in callback {AuthorizationId}"` | `"Unexpected error processing provider callback for authorization {AuthorizationId}"` |

### Structured log placeholder names

Name template parameters in **PascalCase**. These names become property names in structured
logging systems (Seq, Application Insights, etc.), so consistency across services matters
for filtering and aggregation.

| Wrong | Right |
|---|---|
| `{provider}` or `{authorization_id}` | `{Provider}`, `{AuthorizationId}` |
| `{loginId}` or `{SESSION_ID}` | `{LoginId}`, `{SessionId}` |

### Sentence case, no trailing period

Same rule as error messages: capitalize only the first word and proper nouns. No period at
the end.

### Quick reference

```
Before write call (Debug)        → "{Verb-ing} {what} for {entity}"
Bulk read summary (Info)         → "{Verb-ing} {Count} {Type} items [for {entity}]"
External call failure (Error)    → "{Operation noun} failed for {entity}"
Write state transition (Info)    → "{Subject} {past-tense-verb} for {entity}"
Notable condition (Warning)      → "{Event noun phrase} on {entity}"
Unexpected error (Error)         → "Unexpected error {verb-ing} {context}"
Placeholder names                → PascalCase: {Provider}, {LoginId}, {AuthorizationId}
```

---

## Setup pattern

Inject `ILogger<ClassName>` via the constructor. Always use the **concrete class name**
as the type parameter — not the interface name, not a generic `T`. No service locator,
no static logger.

```csharp
public class ProviderAuthService : IProviderAuthService {
    private readonly ILogger<ProviderAuthService> logger;  // concrete class, not IProviderAuthService
    // ... other fields

    public ProviderAuthService(
        ILogger<ProviderAuthService> logger,
        // ... other dependencies
    ) {
        this.logger = logger;
        // ...
    }
}
```

---

## Log statement patterns

### External call — before and on failure
```csharp
logger.LogDebug("Exchanging authorization code with provider {Provider}", provider.Name);
try {
    tokenResponse = await tokenExchangeClient.Exchange(...);
} catch (Exception err) {
    logger.LogError(err, "Token exchange failed for provider {Provider}", provider.Name);
    throw; // or convert to domain exception
}
```

### Persisted state transition
```csharp
providerAuthorization.ConsumedUtc = utcNow;
logger.LogInformation("Provider authorization {AuthorizationId} consumed", providerAuthorization.Id);
```

### Error path that swallows an exception
```csharp
} catch (Exception err) {
    logger.LogError(err, "Unexpected error during callback for authorization {AuthorizationId}",
        providerAuthorization.ErrorRedirectUri);
    return new ErrorRedirectResponse(...);
}
```

### Warning for expected-but-notable condition
```csharp
if (providerAuthorization.ConsumedUtc.HasValue) {
    logger.LogWarning("Replay attempt on authorization {AuthorizationId}", providerAuthorization.Id);
    throw new InvalidAuthorizationRequestRequestException(...);
}
```

---

## What to include in log messages

- **Entity IDs** — always, so you can query the database for the record
- **Provider/resource names** — so you know which external system was involved
- **Error messages** — pass the exception as the first argument to `LogError`/`LogWarning`
  so it appears in structured logs with the full stack trace

Do not include:
- Secrets, tokens, passwords, or private keys — log their key names or IDs instead
- Full request/response bodies — these can be large and may contain PII
- Information that's already in the call stack (e.g. method name)

---

## Applying this skill

When asked to add logging to a service file:

1. Read the file to understand its structure and dependencies.
2. Identify which of the three categories (external calls, state transitions, swallowed
   exceptions) apply and where.
3. For each external call, decide: is it a read or a write?
   - **Write**: add a pre-call Debug and a post-call Info on success.
   - **Bulk read**: add a post-call Info with the result count and key parameters. Skip the pre-call log.
   - **Single read**: skip unless the result is genuinely uncertain (nullable, may not exist). If logging, use Debug.
4. Add `ILogger<ClassName>` to the constructor if not already present (concrete class name, not the interface).
5. Add log statements at the identified points — no more.
6. Summarize what was logged and why, so the user can verify the judgment calls.
