---
name: cli-integration-test
description: >
  How to create integration tests using Pester and a provided CLI program as the
  primary driver. The tests verify the behavior of the underlying system — not the
  CLI tool itself. The provided CLI is made available to the tests via an alias
  or path, and Pester scripts invoke it directly to exercise real system behavior
  end-to-end. Use this skill whenever the user asks to write integration tests,
  create Pester test files, set up test-[feature].ps1 or run-[feature]-[param].ps1
  scripts, or verify system behavior through a CLI tool against a live environment.
  Trigger on: "integration test", "Pester", "test with the CLI", "write a test
  script", or any request to test system behavior end-to-end.
---

# CLI Integration Tests with Pester and a Provided CLI Program

Integration tests live in `[project-root]/integration-tests/`. Two file types per feature, plus a shared requirements document:

```
integration-tests/
├── requirements.md             # Prerequisites for running the tests — keep this current
├── test-[feature].ps1          # Pester test definitions — parameterized, invoked by Pester
└── run-[feature]-[param].ps1   # Runner — bootstraps Pester and invokes the test file
```

The test file defines *what* to verify. The run file defines *how* to invoke it — which environment, provider, or configuration. One test file can have multiple run files for different variants (e.g., `run-bootstrap-sqlserver.ps1` and `run-bootstrap-postgres.ps1`).

---

## The CLI is a driver, not the subject

The goal of these tests is to verify that the **system** behaves correctly — the CLI is simply the tool used to drive it. Keep this distinction in mind:

- A test that provisions a resource via CLI is actually verifying that the system provisioned it correctly.
- A test that queries status is verifying the system's actual state, not the CLI's output format.

This matters most when writing teardown, setup steps, or assertions that the CLI cannot express. The CLI may not expose every operation needed to run a clean test — for example, it may have no command to drop a database, delete a low-level resource, or query raw state.

**When the CLI cannot do something required for the test, stop and ask the human.** Do not:
- Skip the setup or teardown step
- Leave the test incomplete with a TODO
- Assume the operation is unnecessary
- Invent a workaround without confirmation

Ask the human how the gap should be filled — they will decide whether to use a direct database call, a separate script, an SDK, or something else. Write down the answer in the test as a comment and implement it the way the human specifies.

Example gaps that require human input:
- Dropping a test database (the CLI may not expose this)
- Seeding prerequisite data that has no CLI command
- Querying system internals to verify side effects
- Cleaning up resources that are write-only via CLI

---

## test-[feature].ps1 structure

```powershell
#!/usr/bin/env pwsh
#Requires -Modules Pester

param(
    [string]$Param1 = "default-value",
    [string]$Param2
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

BeforeAll {
    # Use a unique ID per run to avoid conflicts between parallel runs or leftover state
    $script:testId = [Guid]::NewGuid().ToString("N").Substring(0, 8)
    # Store any shared state in $script: scope so It blocks can read it
}

AfterAll {
    # Teardown — project-specific. Match it exactly to what the test created.
    # See teardown patterns below.
}

Describe "[Feature] Integration Tests" {
    Context "[Scenario group]" {
        It "Should [expected behavior]" {
            cli-alias command arg1 arg2 | Tee-Object -Variable output
            $LASTEXITCODE | Should -Be 0
        }

        It "Should return expected output" {
            cli-alias command arg1 | Tee-Object -Variable output
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match "expected pattern"
        }

        It "Should fail when [invalid condition]" {
            cli-alias command --bad-arg | Tee-Object -Variable output
            $LASTEXITCODE | Should -Not -Be 0
        }
    }
}
```

Key points:
- Always use `#!/usr/bin/env pwsh` (not `powershell`) as the shebang — `pwsh` is the cross-platform PowerShell Core executable
- Always include `Set-StrictMode -Version Latest`, `$ErrorActionPreference = 'Stop'`, and `$InformationPreference = 'Continue'` at the top of every test file — these catch undefined variables, turn errors into exceptions, and surface `Write-Information` output
- Use `$script:` for any variable shared between `BeforeAll` and `It` blocks
- Append the unique `$script:testId` to resource names (keys, providers, databases) to avoid state leaking between runs
- Always make CLI output visible in the test output — use `Tee-Object -Variable output`, `Write-Host`, or any equivalent approach; visible output is essential for diagnosing failures without re-running the test
- Check `$LASTEXITCODE` after every CLI call — it is the primary pass/fail signal
- `AfterAll` is project-specific — it must undo exactly what the test created

---

## run-[feature]-[param].ps1 structure

```powershell
#!/usr/bin/env pwsh

param(
    [ValidateSet("None", "Normal", "Detailed", "Diagnostic")]
    [string]$Output = "Detailed"
)

if (-not (Get-Module -ListAvailable -Name Pester)) {
    Write-Host "Installing Pester module..." -ForegroundColor Cyan
    Install-Module -Name Pester -Force -Scope CurrentUser -SkipPublisherCheck
}
Import-Module Pester

. "$PSScriptRoot/../alias.ps1"

$config = New-PesterConfiguration
$config.Run.Path = "$PSScriptRoot/test-[feature].ps1"
$config.Run.Parameters = @{
    Param1 = "value-for-this-variant"
    Param2 = "another-value"
}
$config.Output.Verbosity = $Output

Invoke-Pester -Configuration $config
```

The `[param]` suffix in the filename identifies what makes this runner distinct — typically the environment, database provider, or configuration variant. The `$Output` verbosity parameter is standard across all run scripts.

---

## Assertion patterns

| What to check | Pester assertion |
|---|---|
| Command succeeded | `$LASTEXITCODE \| Should -Be 0` |
| Command failed | `$LASTEXITCODE \| Should -Not -Be 0` |
| Output contains text | `$output \| Should -Match "pattern"` |
| Output is exact value | `$output \| Should -Be "exact string"` |
| Output does not contain | `$output \| Should -Not -Match "pattern"` |
| Variable is set | `$script:myVar \| Should -Not -BeNullOrEmpty` |

---

## Teardown patterns

`AfterAll` teardown is project-specific and must undo exactly what the test created. When the CLI does not provide a delete or reset command for something the test created, **ask the human** — do not omit the teardown or leave the test database / resource behind.

**Delete resources created during the test via CLI:**
```powershell
AfterAll {
    cli-alias resource delete $script:createdName --force 2>$null
}
```

**Drop a test database — CLI has no drop command (ask the human; example using Invoke-Sqlcmd):**
```powershell
AfterAll {
    # CLI cannot drop a database — human confirmed: use Invoke-Sqlcmd with a privileged connection
    Invoke-Sqlcmd -Query "DROP DATABASE IF EXISTS [$script:testDbName]" `
        -ServerInstance $ServerInstance -TrustServerCertificate -ErrorAction SilentlyContinue
}
```

**Remove an isolated config root (for config tests):**
```powershell
AfterAll {
    Remove-Item $script:testConfigRoot -Recurse -Force -ErrorAction SilentlyContinue
}
```

Suppress teardown errors with `2>$null` or `-ErrorAction SilentlyContinue` — a failed teardown should not obscure real test failures.

---

## Config isolation

When tests modify configuration (e.g., setting a connection string or base URI), use an isolated config root so tests don't corrupt the developer's real configuration. A common approach is pointing the CLI at a temp directory via environment variable before running test commands:

```powershell
BeforeAll {
    $script:testConfigRoot = Join-Path ([System.IO.Path]::GetTempPath()) "test-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $script:testConfigRoot | Out-Null
    $env:ANCHOR_ConfigRoot = $script:testConfigRoot   # adjust env var name per project
}

AfterAll {
    $env:ANCHOR_ConfigRoot = $null
    Remove-Item $script:testConfigRoot -Recurse -Force -ErrorAction SilentlyContinue
}
```

Check your project's CLI source for how it reads the config root — it is usually an environment variable with a project-specific prefix.

---

## Verify by running the test

After creating or modifying any test file, always run it before declaring the work done. A test that has never been executed may contain syntax errors, reference removed CLI operations, or make wrong assumptions about output format — all of which are silent until you actually run it.

**Find and run the corresponding run script:**

```powershell
# Locate the runner for the test you just wrote or modified
# e.g., for test-login-provider.ps1, look for run-login-provider-*.ps1
pwsh integration-tests/run-[feature]-[param].ps1
```

If no run script exists yet, invoke Pester directly, passing the required parameters:

```powershell
Import-Module Pester
$config = New-PesterConfiguration
$config.Run.Path = "integration-tests/test-[feature].ps1"
$config.Run.Parameters = @{ Param1 = "value"; Param2 = "value" }
$config.Output.Verbosity = "Detailed"
Invoke-Pester -Configuration $config
```

**If tests fail:**

1. Read the Pester failure output — it names the failing `It` block and the assertion that failed.
2. Diagnose whether the failure is a test bug (wrong assertion, stale command name, bad regex) or a real system behavior gap.
3. Fix the test (or the gap, if you introduced a code change that broke behavior).
4. Re-run. Repeat until all tests pass.

Do not hand off or summarize the work as complete while any test is red. The goal is a green run, not a written test.

---

## requirements.md

Maintain a `requirements.md` file in the `integration-tests/` directory. This file tells someone starting from scratch exactly what must be in place before any test can run. It is not a setup guide — it is a checklist of prerequisites.

**Create or update `requirements.md` whenever:**
- You add a new test that depends on something not yet listed
- You discover a prerequisite while writing or debugging a test
- A prerequisite changes (e.g., a different environment variable, a renamed entity)

**What to include:**

```markdown
# Integration Test Prerequisites

## Services
- List any services that must be running (e.g., "Anchor API must be running on localhost:5000")

## Database / seed data
- List any entities or records that must exist before the tests run
  (e.g., "A LoginProvider named 'google' must already exist")
- Note if tests create their own data or rely on shared fixtures

## Environment variables
- List every environment variable the tests read, with a description of what it should contain
  (e.g., `anchorAdmin__configRoot` — path to the CLI config directory)

## CLI tools
- List any CLI aliases or executables required (e.g., "`admin` alias must be set via alias.ps1")

## Other
- Any other setup not covered above (certificates, port forwarding, network access, etc.)
```

Keep entries specific: name the exact variable, exact service, exact entity. Vague entries like "database must be configured" are not useful — "SQL Server must be running at localhost:1433 with database Anchor" is.

If a test file's `BeforeAll` handles a prerequisite automatically (e.g., creates a temp config root, sets an env var), you do not need to list it in `requirements.md` — only list things the test runner must arrange *before* invoking the test.
