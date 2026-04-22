---
name: alba-project
description: >
  How to create and manage the project documentation file for this project.
  A single `project.md` file lives in the `project-mgmt/` folder at the project root.
  It captures business requirements, technical design decisions, key architectural
  choices, open questions, and constraints — the high-level "why and how" context that
  individual task files don't carry. Use this skill whenever the user asks to document
  a project, record a design decision, update business requirements, describe the tech
  approach, capture an architectural choice, or review what has been decided so far —
  even if they just say "document this approach", "record our design decision",
  "update the project doc", "what have we decided?", "capture requirements", or
  "write up the tech design". Trigger on: "project doc", "project.md", "design decision",
  "business requirement", "tech approach", "architecture decision", "what's our approach",
  "project overview", "record requirement", or anything asking for project-level context
  rather than a specific task or work item.
---

# Alba Project Documentation

One file, `project-mgmt/project.md`, captures the project's context at the level that
individual task files cannot: why the project exists, what the business needs, how the
system is designed, and the decisions that shaped it. Tasks record what was done and why
at the task level; the project file records the overall thinking that spans all tasks.

## File location and naming

```
<project-root>/
└── project-mgmt/
    └── project.md
```

There is exactly one `project.md` per project. Create `project-mgmt/` if it does not
exist. Never create multiple project files or date-versioned copies — edit in place.

## File format

```markdown
# <Project Name>

status: <active | on-hold | completed | cancelled>
created: <ISO 8601 timestamp with local UTC offset, e.g. 2026-04-21T10:00:00-04:00>
updated: <ISO 8601 timestamp with local UTC offset>
----

## Business Requirements

What the business needs this project to accomplish — outcomes, not features. Who are
the stakeholders, what problem is being solved, and what does success look like from
a business perspective. Keep this grounded in the business domain, not implementation.

## Technical Design

The chosen technical approach: architecture, key components, technology choices,
integration points, and data flows. Explain the structure and how pieces fit together.
Record the reasoning for significant choices so future readers understand not just
what was built but why it was designed that way.

## Key Design Decisions

Significant choices made during the project — what was decided, what alternatives were
rejected, and the reasoning. Format as a list of discrete decisions. This section grows
over time as decisions get made; add new entries rather than rewriting old ones unless
the decision was reversed.

Example entry:
- **Snapshots are manually triggered, not scheduled**: Allows users to control when
  data is frozen. Scheduled snapshots were rejected because off-cycle corrections
  require re-triggering anyway, making automation misleading.

## Open Questions

Unresolved questions or areas of uncertainty that need to be addressed before or
during implementation. Remove entries once resolved (or move the resolution into
Key Design Decisions if the answer was non-obvious).

## Dependencies & Constraints

Hard constraints, external dependencies, non-negotiable requirements, or platform
limitations that shape the design. Record things that a future developer would need
to know to avoid making choices that break assumptions.
```

- The `----` line closes the metadata block.
- `created` is set once and never changed; `updated` is refreshed whenever the file changes.
- `status` reflects the project's current state, not individual tasks.
- Leave sections empty rather than omitting them — empty sections signal "not yet documented", not "not applicable".

## Creating the project file

1. Check whether `project-mgmt/project.md` already exists (Glob `project-mgmt/project.md`).
2. If it doesn't exist, create `project-mgmt/` (if missing) and write `project.md` with the format above.
3. Set `status: active`, `created: <now>`, `updated: <now>`.
4. Fill in **Business Requirements** and **Technical Design** with what is known. Leave **Key Design Decisions**, **Open Questions**, and **Dependencies & Constraints** with placeholder text or empty if nothing is known yet.
5. If the file already exists, skip to **Updating** below.

**Example:**

```markdown
# Daily & Monthly PnL Snapshot System

status: active
created: 2026-04-21T10:00:00-04:00
updated: 2026-04-21T10:00:00-04:00
----

## Business Requirements

The risk and finance teams need point-in-time snapshots of PnL, exposure, and
risk calculations across FCM accounts so they can reconstruct historical state,
support month-end reporting, and audit past positions. Snapshots must be
available at multiple aggregation levels (account, desk, firm). Users must be
able to trigger a recalculation for a closed period to correct errors.

## Technical Design

Snapshots are stored as immutable records in SQL Server linked to a Period entity
(daily or monthly). A Period has a lifecycle: open → closed. Closing a period
triggers snapshot persistence. Reopening allows recalculation, which overwrites
the prior snapshot for that period. The system can either run its own calculations
or accept externally pre-calculated values, governed by a flag on the trigger request.

Services: `IPeriodService` (lifecycle), `ISnapshotService` (calculation + storage).
Controllers expose endpoints for triggering, querying, and recalculating snapshots.

## Key Design Decisions

- **Snapshots are manually triggered**: Automation was rejected because corrections
  require re-triggering regardless, making scheduled snapshots misleading.
- **Recalculation overwrites**: No versioned snapshot history per period — the
  corrected snapshot replaces the prior one. Audit trail is in the Period audit fields.
- **External pre-calc accepted**: Some FCMs provide pre-calculated values; the system
  accepts them to avoid duplicating calculation logic that the FCM already owns.

## Open Questions

- Should reopening a period also reopen child periods (e.g., daily within a monthly)?
- What is the SLA for snapshot calculation — is async processing needed?

## Dependencies & Constraints

- SQL Server only; no plans to support other databases.
- EF Core 10 with Albatross.EFCore patterns — no raw SQL or Dapper.
- `net10.0` for the main library; `net8.0` for packable client/core libraries.
```

## Updating the project file

When a new decision is made, a requirement is clarified, or a question is resolved:

1. Read the file with the Read tool.
2. Update `updated` to now.
3. Add to **Key Design Decisions** (append; don't overwrite earlier entries unless a decision was reversed).
4. Revise **Business Requirements** or **Technical Design** if the understanding changed — this is a living document, not a log. Rewrite for clarity.
5. Remove resolved items from **Open Questions** (or note the resolution if it was non-obvious and belongs in decisions).
6. Use the Edit tool to apply changes.

## Reading the project file

When asked to summarize the project, review what's been decided, or understand the
current approach:

1. Glob for `project-mgmt/project.md`.
2. If the file doesn't exist, say so and offer to create it.
3. If it exists, Read it and summarize the relevant sections based on what the user asked.

## Relationship to tasks

The project file and task files serve different purposes and should stay in sync conceptually but never duplicate each other:

| project.md | task files (`project-mgmt/*.tsk.md`) |
|---|---|
| Why the project exists | What a specific piece of work accomplishes |
| Architectural and design choices | Task-level reasoning and decisions |
| Business requirements | Task objective |
| Spans the whole project | Scoped to one work item |

When a task-level decision has project-wide implications (e.g., choosing a library,
settling on a data model pattern), record it in the project file's **Key Design Decisions**
section in addition to the task's **Reasoning** section.
