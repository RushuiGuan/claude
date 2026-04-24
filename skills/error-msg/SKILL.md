---
name: error-msg
description: >
  Style guide for writing error messages, exception messages, and validation messages
  consistently in this codebase. Apply this skill whenever the user is writing, reviewing,
  or fixing error messages, exception descriptions, validation failure text, or redirect
  error responses — even if they just say "fix the wording", "make these consistent",
  "review the error messages", or "what should this error say".
---

# Error Message Style Guide

Error messages in this codebase describe what went wrong — not what the caller should do.
Consistent wording makes logs readable and error responses predictable. The rules below
apply to exception messages, validation errors, and redirect error descriptions alike.

---

## Rules

### 1. Describe the state, not an instruction

Say what is wrong. Do not tell the caller what to do.

| Wrong | Right |
|---|---|
| `"Provider parameter is required"` | `"Provider parameter is missing"` |
| `"Please provide a valid state"` | `"State parameter is invalid"` |

### 2. Subject before condition

Name the thing that is wrong, then describe the problem. Avoid leading with an adjective.

| Wrong | Right |
|---|---|
| `"Invalid state parameter"` | `"State parameter is invalid"` |
| `"Missing authorization code"` | `"Authorization code is missing"` |

### 3. Tense by condition type

Choose the tense that fits the situation:

| Condition | Tense | Example |
|---|---|---|
| Something absent | Simple present | `"Authorization code is missing"` |
| Something present but wrong | Simple present | `"State parameter is invalid"` |
| A status condition | Simple present | `"Login provider is inactive"` |
| A time-based condition | Present perfect | `"Authorization request has expired"` |
| A one-time-use violation | Present perfect | `"Authorization request has already been consumed"` |

### 4. Include the name when available

When you know the specific value that caused the error, include it. It saves a lookup.

| Without name | With name |
|---|---|
| `"Login provider is inactive"` | `"Login provider 'google' is inactive"` |
| `"Client not found"` | `"Client 'my-app' not found"` |

### 5. Wrapped exceptions

When catching and rethrowing, keep the original detail. Use this pattern:

```
"{Operation} failed: {detail}"
```

Examples:
- `"Token exchange failed: " + err.Message`
- `"Client secret retrieval failed: " + err.Message`
- `"Id token validation failed: " + err.Message`

Do not rephrase `err.Message` — append it as-is so the root cause is preserved.

### 6. Sentence case, no trailing period

Capitalize only the first word and proper nouns. No period at the end.

| Wrong | Right |
|---|---|
| `"authorization request has expired."` | `"Authorization request has expired"` |
| `"Login Provider Is Not Active"` | `"Login provider is inactive"` |

---

## Quick reference

```
Something is missing        → "{Subject} is missing"
Something is wrong          → "{Subject} is invalid"
Something is off/disabled   → "{Subject} is inactive"
Time-based expiry           → "{Subject} has expired"
Already used                → "{Subject} has already been {consumed/processed/used}"
Wrapped exception           → "{Operation} failed: {detail}"
```

---

## Applying this skill

When reviewing existing messages, scan for:
- Instructions instead of descriptions ("is required", "must be", "please provide")
- Adjective-first phrasing ("Invalid X", "Missing X")
- Wrong tense for the condition type
- Missing subject name when the name is available in scope
- Title Case or trailing periods

When writing a new message, pick the condition type from the quick reference and fill in the subject.
