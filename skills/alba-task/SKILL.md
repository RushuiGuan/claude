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

## The purpose of a task file

A task file is not a work log — it is a briefing document for whoever executes the work.
A well-written task should contain enough context that a future agent (or human) picking
it up cold — without any conversation history — can execute the work correctly, make
good judgments about edge cases, and skip the exploratory work that went into scoping it.

This means:
- **Objective** states the goal in terms of what changes and why it matters, not a list of steps.
- **Reasoning** captures the landscape: which files are relevant, what patterns apply,
  what constraints exist, what was found during scoping, and what open questions remain.

The richness of Reasoning is what makes the task file valuable. Thin reasoning = the
executor starts from scratch. Good reasoning = the executor can dive straight in.

## Creating a task: plan before writing

Task creation is a two-phase process: **discover first, write second.** Do not write
the task file until you have enough context to write it well.

### Phase 1: Discover requirements

Gather context from two sources — the user and the codebase — and use both.

**From the user:**
Ask targeted questions if the scope is unclear:
- Which service, model, controller, or area is in scope?
- What outcome does the user expect?
- Are there patterns to follow or things to avoid?
- Is this related to an existing task?

If the user's intent is clear and specific, targeted questions suffice. If the request
is vague ("review X", "clean up Y", "add Z"), lean toward scanning the code first and
bringing findings back to the user rather than asking abstract questions.

**From the codebase:**
Read relevant files proactively before writing any task content.
- Read `project-mgmt/project.md` if it exists — ground the task in the broader project
  purpose so the Objective connects to business goals, not just technical steps.
- Scan existing task files for related or overlapping work.
- Read the target source files (service, model, controller, etc.) to identify specific
  issues, gaps, or considerations worth capturing in Reasoning.

The goal is to arrive at the draft with concrete findings, not abstract intentions.
For example: instead of "review the AccountService", the Reasoning should name the
specific methods that need attention, the constraints that apply, and what a correct
outcome looks like.

### Phase 2: Draft and confirm

Present a draft task to the user *before* writing the file to disk:

1. Show the proposed title, objective, and reasoning with your concrete findings.
2. Flag any assumptions made and invite correction.
3. Note any open questions that the task executor will need to resolve.

Wait for a signal — even a brief "looks good" or "done" — before writing the file.
Don't ask for confirmation on minor wording. Only confirm scope and reasoning accuracy.

Once confirmed, write the task with `status: new` and leave **Conclusion** blank.

**Example of rich Reasoning (the goal to aim for):**

```markdown
## Reasoning

`AccountService.CreateUserAccount` currently accepts a raw `Login` entity, but
`LoginService` changed its return type in a recent refactor — the service now needs
to accept a login ID and resolve it internally via `IAnchorRepository.GetRequiredLogin`.

Affected files:
- `Anchor/Services/AccountService.cs` — `CreateUserAccount`, `CreateClientAccount`
- `Anchor.Web/Controllers/V1/AccountController.cs` — two call sites pass raw `Login`
- `Anchor/Services/TenantService.cs` — `CreateTenant` also calls this path

Constraints:
- Do not change the public `IAccountService` interface signature in this pass —
  only the implementation and its internal collaborators.
- Follow the existing pattern in `ClientService.CreateClient` where the service
  resolves the entity from a repository rather than accepting it as a parameter.

Open question: should the actorId be optional here? It is nullable in `CreateTenant`
but required everywhere else. Confirm with user before deciding.
```

## Project context and escalation

Read `project-mgmt/project.md` before creating any task. Use it to:
- Frame the Objective in terms of project goals rather than isolated technical work.
- Ensure Reasoning is consistent with architectural decisions already on record.
- Avoid restating project-wide context inside the task — reference the decision instead.

### When to escalate to project.md

During task planning, watch for findings that are bigger than this task. Escalate when
you encounter something that applies across multiple work items or would govern how
future work gets done:

- A naming or structural convention that should be consistent across the codebase
  ("service methods resolve entities internally; they don't accept raw entity objects")
- An architectural boundary that isn't already documented
  ("controllers own the transaction boundary, services never call SaveChanges directly")
- A technology or library choice that constrains all future work in the area
- A standing rule the user states as policy ("we always do X", "the rule is Y")
- A constraint discovered in the codebase that anyone touching this area needs to know

If the finding only affects the specific files and methods in scope for this task, keep
it in the task's Reasoning. If it would affect anyone touching adjacent code in the
future, it belongs in `project.md`.

### How to escalate

1. Write the decision to `project.md` in the appropriate section (follow `alba-project`
   conventions):
   - Cross-cutting pattern or architectural choice → **Key Design Decisions**
   - External dependency or hard platform limit → **Dependencies & Constraints**
   - Unresolved question that needs an answer before or during implementation → **Open Questions**
   - Update `updated` in the metadata block.

2. In the task's Reasoning, reference the decision rather than restating it:
   > Follows the project convention recorded in project.md: service methods resolve
   > entities from the repository rather than accepting them as parameters.

This keeps each file focused on its own level. `project.md` owns the pattern;
the task owns the instance of applying it.

## Updating a task

When status changes or the conclusion is ready:

1. Read the file with the Read tool.
2. Update the `status` field.
3. Fill in or update the **Conclusion** section.
4. If reasoning evolved during the work, update **Reasoning** to reflect the final
   understanding — it is not a log, so rewriting for clarity is fine.
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
