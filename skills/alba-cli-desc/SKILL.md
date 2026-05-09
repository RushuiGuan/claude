---
name: alba-cli-desc
description: Generate Description strings for Albatross.CommandLine CLI verbs, options, and arguments. Use this skill whenever the user asks to add, write, fill in, or improve Description values on [Verb], [Option], or [Argument] attributes in an Albatross.CommandLine project — even if they just say "add descriptions" or "document this command".
---

# alba-cli-desc

Generates `Description` strings for `[Verb]`, `[Option]`, and `[Argument]` attributes in **Albatross.CommandLine** projects.

## Step 1 — Read two sources for every verb

For each verb you're documenting, read **both**:

1. **The params class** — the `[Verb]` attribute, all `[Option]`/`[Argument]` properties, and their types.
2. **The handler's `InvokeAsync` method** — this reveals what the command actually does: which service it calls, what data it sends, and what filtering or transformation happens.

The handler is the ground truth for intent. The params class alone is often ambiguous — a `bool Force` property doesn't explain itself, but seeing it passed to `SyncInstrument(id, force, ...)` makes the semantics clear. Similarly, a handler that builds a command and calls `commandClient.Submit(...)` tells you this verb is fire-and-forget, not a synchronous operation.

## Step 2 — Write the verb Description

The verb description is the one-line summary shown in `--help`. Write it as an **imperative statement** — describe what the command does and to what. Be specific about the entity and operation; avoid vague words like "manage" or "handle".

**Formula:** `[Action verb] [target entity] [key qualifier if scope matters]`

**Good examples:**
- `"Sync all currencies from SecMaster"` — unconditional; handler calls `SyncCurrency()` with no filters
- `"Queue a background job to bulk-sync instruments from SecMaster"` — handler submits a command asynchronously, not inline
- `"Sync instruments by their identifiers"` — handler calls `SyncInstrument` per ID

**Poor examples:**
- `"Currency synchronization"` — noun phrase, not an action
- `"Bulk instrument sync"` — vague, doesn't say what "sync" means here

Read the handler to determine scope: if it loops unconditionally, say "all"; if it passes filters, name them.

## Step 3 — Write option and argument Descriptions

### Properties with `[UseOption<T>]` or `[UseArgument<T>]`

**Do not add a description** to these properties unless the user explicitly asks to override one. The reusable option/argument type already carries its own description, which exists precisely for consistency across commands. Adding a duplicate or conflicting description defeats that purpose.

If the user does ask to override, use the `Description` property on the `[UseOption]` or `[UseArgument]` attribute itself — do **not** add a new `[Option]` or `[Argument]` attribute alongside it:

```csharp
// Override — only when explicitly asked
[UseOption<TradeDateOption>(Description = "As-of date for resolving instrument contract details")]
public DateOnly TradeDate { get; init; }
```

### Plain `[Option]` and `[Argument]` properties

Each description explains **what the user is specifying** — the role of that input in the command's operation.

**Rules:**
- One line only
- Do **not** mention the default value — System.CommandLine appends `[default: x]` automatically
- Do **not** list enum choices — System.CommandLine lists them automatically
- Do **not** repeat the property name back to the user (`"The trade date"` for a `TradeDate` property adds nothing)
- Write in terms of effect: say what it controls or filters

**Examples:**

| Property | Bad description | Good description |
|---|---|---|
| `bool Force` | "Force flag, default false" | "Overwrite the existing record even if it already exists" |
| `InstrumentStatus? InstrumentStatus` | "The instrument status (Active, Inactive)" | "Filter by instrument lifecycle status" |
| `bool MarketStatus` | "Market status, true by default" | "Include only instruments whose market is currently active" |

## Output format

Output ready-to-paste attribute lines. Group by verb when handling multiple commands.

```csharp
// sync bulk-instrument
[Verb<BulkSyncInstrument>("sync bulk-instrument",
    Description = "Queue a background job to bulk-sync instruments from SecMaster")]

// UseOption properties — no description added (reusable option owns it)
[UseOption<MarketOption>]
public MarketSummary? Market { get; init; }

[UseOption<SecurityTypeOption>]
public SecurityType SecurityType { get; init; }

[UseOption<TradeDateOption>]
public DateOnly TradeDate { get; init; }

// Plain Option properties — description added here
[Option(DefaultToInitializer = true, Description = "Include only instruments whose market is currently active")]
public bool MarketStatus { get; init; } = true;

[Option(Description = "Filter by instrument lifecycle status")]
public InstrumentStatus? InstrumentStatus { get; init; }
```
