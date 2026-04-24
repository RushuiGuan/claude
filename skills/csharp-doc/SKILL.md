---
name: csharp-doc
description: >
  Generates XML triple-slash (///) documentation comments for C# projects following
  the Albatross convention: meaningful comments only, never parroting the symbol name.
  Use this skill whenever the user asks to document, add comments to, or generate XML
  docs for a C# file, project, or solution — even if they just say "add docs" or
  "comment this class". Also trigger when the user says "add triple slash comments",
  "generate XML documentation", "document the public API", or similar.
---

# C# XML Documentation Skill

The goal is **useful documentation** — not coverage. A comment that just restates
the symbol name adds noise and makes real comments harder to find. Write a comment
only when it conveys something the name alone does not: intent, constraints,
side-effects, non-obvious behavior, or usage guidance.

## Scope detection

Determine the scope from the user's request:
- **File**: one `.cs` file specified or implied
- **Project**: a `.csproj` and all `.cs` files beneath it
- **Solution**: a `.sln` and all projects within it

If ambiguous, ask the user to clarify before proceeding.

## What to document

Apply `///` comments to **public and protected** symbols only (classes, structs,
interfaces, enums, constructors, methods, properties, fields, events, delegates).

**Skip entirely:**
- Default constructors (parameterless, no custom logic)
- Any symbol whose name + signature already tells the complete story with no
  room for misunderstanding (e.g. `IsEmpty`, `Count`, `ToString`, `public string Name { get; set; }`)
- Internal, private, and file-scoped symbols

The bar is: *would a competent C# developer pause and wonder about this?*
If no, skip it.

## Tags to use

| Tag | When to include |
|-----|----------------|
| `<summary>` | Always, when documenting a symbol |
| `<param name="...">` | Every parameter — but only meaningful descriptions, not "the foo parameter" |
| `<returns>` | When the return value needs explanation beyond the type name |
| `<exception cref="...">` | When the method explicitly throws, or rethrows a specific exception |
| `<remarks>` | For complex types/methods — include a short code sample if it clarifies usage |

## Comment quality rules

1. **Don't restate the name.** `GetUser` → don't write "Gets the user." Write what makes it distinct: which user store, what happens if not found, caching behavior, etc.

2. **Be concise.** One clear sentence beats three vague ones. Trim filler like "This method..." or "This property represents...".

3. **Param descriptions add context.** Instead of "The id", write "Database primary key of the user record" or "Must be positive; throws if zero or negative."

4. **Remarks + code samples for complex types.** If a class has non-obvious initialization, ordering requirements, or a typical usage pattern, include a `<remarks>` block with a `<code>` example.

5. **Exceptions are contractual.** Only document exceptions the method itself throws (or explicitly re-throws). Don't list every possible CLR exception.

## Overwrite policy

Always overwrite existing `///` comments — don't preserve stale or low-quality docs.

## Format

Use multi-line style for summaries longer than ~80 characters; single-line otherwise.

```csharp
// Single-line summary
/// <summary>Returns the user matching <paramref name="id"/>, or null if not found.</summary>

// Multi-line summary
/// <summary>
/// Validates the incoming request against the registered rule set and returns
/// a <see cref="ValidationResult"/> containing all violations found.
/// </summary>

// Full example with params, returns, exception, remarks
/// <summary>
/// Commits all pending changes in the current session to the database.
/// </summary>
/// <param name="cancellationToken">Token to cancel the async operation.</param>
/// <returns>Number of rows affected.</returns>
/// <exception cref="DbUpdateConcurrencyException">
/// Thrown when an optimistic concurrency conflict is detected.
/// </exception>
/// <remarks>
/// Call this once per request at the controller boundary. Calling it multiple
/// times in the same scope is safe but unnecessary.
/// <code>
/// var affected = await session.SaveChangesAsync(ct);
/// </code>
/// </remarks>
```

## Workflow

1. Read the target file(s) to understand the codebase.
2. For each public/protected symbol, apply the "skip" rules first.
3. For symbols that warrant documentation, draft the comment using only the tags
   that add value — not all tags every time.
4. Write the updated files. Do not change anything other than the `///` comments.
5. Briefly summarize what was documented and what was intentionally skipped, so
   the user can verify the judgment calls.
