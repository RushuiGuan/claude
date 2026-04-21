---
name: alba-task
description: >
  How to create and manage task files in this project. Each task lives in its own
  file under the `task-mgmt/` folder at the project root, named `[task-name].tsk.md`.
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

Tasks live in `task-mgmt/` at the project root. Each task is its own file named
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

## Creating a task

1. Choose a descriptive kebab-case name: `[task-name].tsk.md`
2. Place it in `task-mgmt/` at the project root.
3. Set `status: new`, `created: <now>`, `priority: normal` unless specified otherwise.
4. Fill in **Objective** and **Reasoning** with what's known at creation time.
5. Leave **Conclusion** blank — fill it in when the work is complete.

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

1. Use Glob to find all `task-mgmt/*.tsk.md` files.
2. Read each and extract status, priority, and the first line of the Objective.
3. Present results grouped by status or priority as asked.

## Valid field values

| Field    | Values                                      | Default           |
|----------|---------------------------------------------|-------------------|
| status   | `new`, `started`, `cancelled`, `completed`  | `new`             |
| priority | `low`, `normal`, `high`                     | `normal`          |
| created  | ISO 8601 timestamp with local UTC offset    | (set at creation) |
| tags     | space-delimited free-form labels            | (omit if none)    |
