---
name: nuget-readme
description: >
  Generates a README.md for an Albatross NuGet package following the established template:
  summary, Key Features, Quick Start with code sample, Dependencies, Prerequisites, and
  Documentation links. Use this skill whenever the user asks to create, write, or update
  a README for a NuGet package or library project — even if they just say "write the README"
  or "add a README to this project". Also trigger when the user says "document this package",
  "create the nuget readme", or "add readme documentation".
---

# NuGet README Skill

NuGet READMEs are summaries — not full documentation. The goal is to orient a developer who
lands on the package page in under two minutes: what it does, whether it fits their needs,
and where to learn more. Keep everything concise; link to the real docs for depth.

## Workflow

1. **Read the project** — read the `.csproj` file and, if present, `Directory.Build.props`
   in the parent directory. Extract:
   - Package name, description, and any existing summary text
   - `PackageProjectUrl` (may be in either file — prefer `.csproj` if set there)
   - Dependencies (`<PackageReference>` entries, excluding dev/build-only tools)
   - Target framework(s) and any minimum SDK/compiler requirements

2. **Read the source** — scan the public API (interfaces, key classes, extension methods)
   and any existing XML doc comments to understand what the package actually does.

3. **Find doc links** — look for a `docfx_project` directory at the solution root.
   If it exists, scan `docfx_project/articles/` for article files whose topics are
   relevant to this specific package. Use only applicable ones — don't list every article.

4. **Write the README** using the structure below.

---

## README Structure

Follow this section order exactly. Do not add, rename, or reorder sections.

### Header
```
# PackageName
```
The package name as registered on NuGet (e.g. `Albatross.EFCore`).

### Summary (no heading)
Immediately after the header — no `## Summary` subheading, that would be redundant.
Write 2–4 sentences: what the package does, the problem it solves, and who it's for.
Match the confident, concise tone of the template — lead with value, not implementation detail.

### ## Key Features
Bullet list. Each bullet: bold short label, dash, one sentence of value.
Focus on what makes this package worth using. Skip obvious or generic points.

```markdown
## Key Features
- **Automatic Registration** - Source generator discovers all `EntityMap<T>` classes; no manual wiring needed
- **Provider Abstractions** - Constraint-violation detection is provider-agnostic; swap SQL Server for PostgreSQL without touching service code
```

### ## Quick Start
One focused, runnable code sample showing the most common use case. Add a brief
sentence before the code block to set context. If setup and usage are distinct steps,
use numbered subheadings (`### 1. Install` / `### 2. Configure`), but keep it minimal.

Do not try to show everything — pick the single most useful example.

### ## Dependencies
List runtime `<PackageReference>` dependencies with their minimum versions.
If the package has no runtime dependencies, say so explicitly:

```markdown
## Dependencies
- No external runtime dependencies.
```

Omit build-time / dev-only packages (source generators, analyzers, design-time tools).

### ## Prerequisites
Minimum .NET SDK, C# compiler version, or runtime version required. One or two bullets.

### ## Documentation
Use `PackageProjectUrl` as the primary documentation link:

```markdown
## Documentation

**[Complete Documentation](PackageProjectUrl)**
```

If a `docfx_project` exists and has applicable articles, add a `### Links` subsection
with bold links to only the relevant articles. Use descriptive anchor text — not file names.
If there are no applicable articles, omit the `### Links` subsection entirely.

---

## Quality checks before writing

- Summary does not start with "This package..." — lead with what it does, not what it is
- Key Features bullets are specific to this package, not generic library praise
- Quick Start code compiles (or is clearly pseudocode with `...` placeholders)
- Dependencies section exists even if empty
- Documentation URL comes from `PackageProjectUrl`, not hardcoded
- No section is skipped unless explicitly noted above as conditional
