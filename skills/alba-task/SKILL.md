---
name: alba-task
description: >
  How to create and manage task files in this project. Each task lives in its own
  file under the `project-mgmt/` folder at the project root, named `[task-name].tsk.md`.
  Task files document the objective, reasoning, decisions, and conclusion — not a
  running process log, but a concise record of *why* something was done and *what*
  the outcome was. Use this skill whenever the user asks to create a task, add a task,
  record a decision, document reasoning, update task status, list tasks, or close out
  a task with a conclusion — even if they just say "create a task for X", "log what we
  decided", "mark this done", or "what tasks are open". Trigger on: "create a task",
  "add task", "new task", "record this decision", "document this", "update task",
  "mark task complete", "show tasks", "list tasks", or anything involving task tracking
  or decision documentation in the project.
---

# Alba Task Management

Tasks live in `project-mgmt/` at the project root. Each task is its own file named
`[task-name].tsk.md` using kebab-case (e.g., `audit-entity-fields.tsk.md`).

## File format

```
# Task Title

status: <new | started | cancelled | completed>
created: <ISO 8601 timestamp with local UTC offset, e.g. 2026-04-21T10:00:00-04:00>
priority: <low | normal | high>
tags: <space-delimited tags>
----

## Objective

What needs to be done and why — the goal, not the steps.

## Reasoning

Background, constraints, design decisions, trade-offs considered, and anything that
explains *why* the approach was chosen. This is the most valuable section for future
readers — capture the thinking that isn't obvious from reading the code or the outcome.

## Conclusion

What was actually done and what the result was. Written after the work is complete.
```

- The `----` line closes the metadata block.
- `priority` defaults to `normal` if omitted. `tags` is optional.
- `created` is set once and never changed.
- `status` progresses: `new` → `started` → `completed` (or `cancelled`).
- Leave **Conclusion** empty (or omit it) until the task is done.

## Project context

Before creating or updating a task, check whether `project-mgmt/project.md` exists
and read it if it does. The project file captures the business requirements, technical
design, and key design decisions that span all tasks. Use it to:

- Ground the task's **Objective** in the business purpose rather than just the
  technical steps.
- Ensure the task's **Reasoning** is consistent with architectural decisions already
  recorded in the project file.
- Avoid duplicating project-wide context in the task — link to the relevant decision
  instead of restating it.

While working on a task, stay alert for project-level context that surfaces — new
requirements the user mentions, architectural choices that get made, constraints that
emerge, or open questions that get resolved. When this happens, update `project.md`
immediately rather than waiting until the task is complete:

- New business requirement → add to **Business Requirements**
- Architectural or design choice → add to **Key Design Decisions**
- Emerging constraint → add to **Dependencies & Constraints**
- Resolved uncertainty → remove from **Open Questions** (or record the answer in
  **Key Design Decisions** if the resolution was non-obvious)

Update `updated` in the metadata block each time. Don't ask the user whether to update
it — just do it as part of the work. The project file should reflect the current
understanding of the project at all times.

## Creating a task

1. Read `project-mgmt/project.md` if it exists, to understand the project context.
2. Choose a descriptive kebab-case name: `[task-name].tsk.md`
3. Place it in `project-mgmt/` at the project root.
4. Set `status: new`, `created: <now>`, `priority: normal` unless specified otherwise.
5. Fill in **Objective** and **Reasoning** with what's known at creation time.
6. Leave **Conclusion** blank — fill it in when the work is complete.

**Example:**

```markdown
# Audit Entity Audit Fields

status: new
created: 2026-04-21T10:00:00-04:00
priority: normal
tags: entities audit
----

## Objective

Go through every EF Core entity in Anchor.Models and ensure each has the correct
audit fields (CreatedUtc, CreatedById) and a matching CreatedBy navigation property
with entity map configuration.

## Reasoning

Audit fields provide traceability for all data mutations. The rule is:
- Normal entities: both CreatedUtc and CreatedById
- Flow-state entities (AuthorizationCode, Jti, etc.): CreatedUtc only — no actor to attribute
- Exceptions (ClientPublicKey): neither — schema controlled by crypto library

CreatedBy nav property is required alongside CreatedById so EF can enforce the FK
and allow eager loading of the actor when needed.

## Conclusion
```

## Updating a task

When status changes or the conclusion is ready:

1. Read the file with the Read tool.
2. Update the `status` field.
3. Fill in or update the **Conclusion** section.
4. If reasoning evolved during the work, update **Reasoning** to reflect the final understanding — it's not a log, so rewriting for clarity is fine.
5. Use the Edit tool to write changes.

## Listing / querying tasks

When asked to see tasks (e.g., "what's open?", "show high priority tasks"):

1. Use Glob to find all `project-mgmt/*.tsk.md` files.
2. Read each and extract status, priority, and the first line of the Objective.
3. Present results grouped by status or priority as asked.

## Valid field values

| Field    | Values                                      | Default           |
|----------|---------------------------------------------|-------------------|
| status   | `new`, `started`, `cancelled`, `completed`  | `new`             |
| priority | `low`, `normal`, `high`                     | `normal`          |
| created  | ISO 8601 timestamp with local UTC offset    | (set at creation) |
| tags     | space-delimited free-form labels            | (omit if none)    |
