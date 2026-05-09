---
name: csharp-dependency
description: Navigates private/internal NuGet packages to their local source using dependency.md at the project root. Trigger this skill autonomously — no user prompt needed — whenever: (1) you encounter a package reference in a .csproj or using statement that isn't a well-known public package; (2) you need to read a type, interface, method, or pattern from a private library; (3) you are about to search .nuget/packages/, run dotnet commands to inspect a package, or visit external docs for a package that may be private; (4) the user asks to add or update entries in dependency.md. Always check dependency.md first — it tells you where the source lives locally.
---

# C# Dependency Map

This skill maintains `dependency.md` at the project root. It maps private NuGet packages to their local source code and documentation so agents can navigate private dependencies without guessing.

## When to read dependency.md

Read it whenever you encounter an unfamiliar package reference in `.csproj` files or `using` statements that isn't a well-known public package. Find the matching entry by package ID (exact or wildcard match), then use the recorded paths to navigate directly.

## When to update dependency.md

Update it when:
- The user asks to add or update a dependency entry
- You discover a private package that isn't yet recorded
- A path changes or a documentation source becomes available

Always verify paths before writing (see below).

## dependency.md format

All paths are relative to `dependency.md` (the project root). Entries are grouped by upstream project, not by individual package.

```markdown
## <Project Name>

### Path
<path to the repo/solution root — relative to dependency.md>

### Documentation
<subfolder relative to Path, or a URL> — omit if none

| Package ID | Source |
|------------|--------|
| <packageid> | <source subfolder relative to Path> |
```

Full example:

```markdown
## Albatross EFCore

### Path
..\efcore

### Documentation
docfx_project

| Package ID | Source |
|------------|--------|
| albatross.efcore | Albatross.EFCore |
| albatross.efcore.admin | Albatross.EFCore.Admin |
| albatross.efcore.codeGen | Albatross.EFCore.CodeGen |
| albatross.efcore.sqlserver | Albatross.EFCore.SqlServer |
```

All subfolders (Documentation and Packages) are relative to `Path`. To resolve any of them: join Path + subfolder.
For example, `albatross.efcore.sqlserver` → `..\efcore` + `Albatross.EFCore.SqlServer` → `..\efcore\Albatross.EFCore.SqlServer`.
Documentation → `..\efcore` + `docfx_project` → `..\efcore\docfx_project`.

## Adding entries with a wildcard package ID

When the user supplies a wildcard (e.g., `albatross.efcore.*`) to add a new dependency:

1. Search all `.csproj` files in the project for package references matching the wildcard pattern
2. For each matched package ID, find its source subfolder in the upstream project's Path (look for a folder whose name matches the package name)
3. Verify each source path exists before recording it
4. Create one entry per matched package as a table row under the appropriate project heading

Only record packages that are actually referenced in the project — don't enumerate every package in the upstream repo.

## Verifying paths before writing

Before recording any Path, Documentation subfolder, or package subfolder:
- Use Glob with the resolved path as a pattern, or Read a known file inside the directory
- Resolve `Path` against `dependency.md` (project root); resolve Documentation and package subfolders against `Path`
- If a path doesn't exist, tell the user — don't record a broken path
- Documentation given as a URL doesn't need local verification

## Navigating source after reading

- Use **Path** (+ Source from Packages table) to jump to a specific assembly's source
- Use **Path** alone when you need broader repo context: sibling packages, tests, build files
- Resolve relative paths against the project root before using them as file system paths

## When a dependency path is missing

If you resolve a path from `dependency.md` and the directory does not exist on disk,
**do not change the recorded path** — the path is correct for the team; only this
machine is missing the repo.

Tell the user:

> The source for `<package-id>` is not available at `<resolved-path>`.
> Clone or download the `<Project Name>` repository to that location and try again.

The recorded path is the canonical team location. Changing it to wherever the user
happens to have the repo would break the entry for everyone else.

## Instead of these approaches

When you need a type, method, or interface from a private package:
- Do NOT search `.nuget/packages/`
- Do NOT use `dotnet list`, `dotnet inspect`, or reflection tools
- Do NOT navigate NuGet.org or external documentation

Read dependency.md, resolve the path, and read the source directly.

## Resolving a path

1. Take `Path` from the entry (relative to the project root where dependency.md lives)
2. Append the `Source` column value for the specific package
3. Use Glob or Read on the result

Example: `Albatross.EFCore` → Path `../efcore` + Source `Albatross.EFCore`
→ resolve against `C:\app\anchor` → `C:\app\efcore\Albatross.EFCore`
→ Glob `C:\app\efcore\Albatross.EFCore\**\IRepository.cs`
