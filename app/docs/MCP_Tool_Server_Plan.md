# In-Process MCP Tool Server — Implementation Plan

> **Scope decision:** Lite mode only (~16 tools). No queue/async support — synchronous task execution only.
> No `OmitCommit` — all calls go through the dispatcher with default commit behavior.
> `invoke_message_type` is the universal fallback for anything not in the named tool set.

## Problem Statement

The Bifrost Chat needs an in-process tool server that exposes Bifrost message types
as tools for any AI chat provider. `AnthropicToolRunner` in the Anthropic app **already
proves** the pattern works: it exposes message types as tools and executes them via
`Dispatcher ori` directly, with zero HTTP. We generalize this into a public
codeunit in the core app that any provider can use.

## Target Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Chat Provider (Anthropic / OpenAI / Local LLM / etc.)      │
│  Runs the agentic tool loop                                 │
└──────────────────────────┬──────────────────────────────────┘
                           │ Bootstrap / ListTools / CallTool
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  MCP Tool Server ori  (Public codeunit in Core app)      │
│  ─ Session bootstrap (system prompt + identity + primer)    │
│  ─ Tool registry (~16 tools, lite mode)                     │
│  ─ Argument mapping (tool input → Bifrost envelope)         │
│  ─ Response mapping (Bifrost response → tool result text)   │
│  ─ OnlyEnabled filter (only message types with Enabled=true)│
│  ─ Blob store (large base64 ↔ reference tokens)            │
└──────────────────────────┬──────────────────────────────────┘
                           │ Execute(MessageType, ...)
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Dispatcher ori  (existing)                    │
│  ─ Full pipeline (queue entry, language switch, commit)     │
│  ─ No OmitCommit — always commits normally                  │
└──────────────────────────┬──────────────────────────────────┘
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  Message Type Implementations (existing enum + codeunits)   │
└─────────────────────────────────────────────────────────────┘
```

---

## Target Code Path

```
Any provider → MCP Tool Server ori → Bifrost Dispatcher → Message Type Impl
```

All tool calls are in-process. No external servers, no HTTP, no OAuth.

---

## Session Bootstrap

When a chat session starts, the provider must call `MCP Tool Server ori.Bootstrap()` to prepare the session context.

### Bootstrap Sequence (mandatory, in order)

| Step | Action | Returns |
|------|--------|---------|
| **1. Identity** | Dispatches `Help.WhoAmI.Get` | User info, language, permissions, pending notifications |
| **2. Memory overview** | Dispatches `Memory.User.List` + `Memory.Company.List` | Descriptions of stored memories (not full content) |
| **3. System prompt** | Reads `systemPrompt` from WhoAmI response | Admin-injected behavioral instructions |
| **4. API primer** | Dispatches `Help.Bifrost.Get` then `Help.Implementation.Get` (subject: `Help.Bifrost.Get`) | Full API usage rules (tableView syntax, CalcSums, pagination, etc.) |

### Bootstrap Output

`Bootstrap()` returns a `Text` value containing the composed system prompt:
1. Base system prompt (rules for BC chat assistant)
2. Identity context (user name, company, language, permissions)
3. Memory overview (titles/descriptions of available memories)
4. Admin system prompt (if any)
5. API primer (Bifrost usage rules — prevents query/write mistakes)
6. Record context (if the user is viewing a specific record — table ID, SystemId)

The provider feeds this as the `system` parameter to the LLM.

### Language Handling

- `who_am_i` returns `personalization.languageId` — this is **only** used to tell the chat model what language to reply in (included in the system prompt).
- The tool server does **not** store or pass LCID to tools. The dispatcher always uses the current BC session language (`GlobalLanguage()`) automatically.
- No `lcid` parameter on any tool. Language switching is handled by BC, not the tool server.

---

## New Codeunits

### 1. `MCP Tool Server ori`

| Property | Value |
|----------|-------|
| **File** | `app/src/BifrostChat/CEMCPToolServer.Codeunit.al` |
| **Object ID** | TBD (within 10077885–10078384) |
| **Access** | Public |
| **SingleInstance** | Yes (caches tool registry + session state) |

#### Public API

```al
/// Runs the session bootstrap sequence and returns the composed system prompt.
/// Must be called once at chat session start before any tool calls.
/// RecordContext is optional JSON with tableId + recordSystemId for page-contextual chat.
procedure Bootstrap(RecordContext: Text): Text

/// Lists all available tools with their input schemas (~16 tools).
procedure ListTools(var Tools: JsonArray)

/// Executes a tool by name. Returns true on success (even if the tool itself reports an error).
/// IsError=true means the tool executed but returned a business error.
procedure CallTool(ToolName: Text; Arguments: JsonObject; var ResultText: Text; var IsError: Boolean): Boolean

/// Returns the count of registered tools.
procedure GetToolCount(): Integer

```

#### Internal State (SingleInstance)

- `ToolRegistry: JsonArray` — cached tool definitions (built once)
- `IsBootstrapped: Boolean` — guards against calling tools before bootstrap
- `BlobStore: Dictionary of [Text, Text]` — blob reference → base64 data

### 2. `MCP Tool Executor ori`

| Property | Value |
|----------|-------|
| **File** | `app/src/BifrostChat/CEMCPToolExecutor.Codeunit.al` |
| **Object ID** | TBD |
| **Access** | Internal |
| **SingleInstance** | Yes |

Wraps `Dispatcher ori.Execute()` inside `Codeunit.Run()` for isolation. Write tools that fail don't roll back the chat session.

```al
procedure SetParameters(MessageType: Enum "Message Type ori"; Subject: Text; RequestText: Text)
procedure GetResponseText(): Text
procedure GetResponseContentType(): Text
trigger OnRun()  // calls Dispatcher.Execute
```

---

## Blob Store (Large Binary Data Handling)

### Problem

Some message types return binary data (PDFs, images, Excel files) and some accept
binary input. Passing large base64 blobs through the LLM context window wastes tokens
and can exceed context limits. The model doesn't need to read or reason about binary
data — it just needs to pass it from one tool call to the next.

### How Content Types Flow

The `Dispatcher ori` returns a `ResponseContentType` for every call.
The executor uses this to decide pass-through vs blob store:

**Pass through (readable text):**

| Content Type | Example |
|-------------|---------|
| `text/json` | Data.Records.Get, Help.MessageTypes.Get (default for most message types) |
| `text/markdown` | Help.Implementation.Get |
| `text/xml` | XML responses |
| `text/csv` | CSV.Records.Get |
| `text/plain` | Plain text responses |
| `application/json` | Some implementations set this instead of text/json |
| `application/xml` | Some XML responses |

**Blob store (binary):**

| Content Type | Example |
|-------------|---------|
| `application/pdf` | Sales.Invoice.GetPdf |
| `application/octet-stream` | Email attachments, file downloads |
| `image/*` | Report thumbnails, images |
| Everything else | Any content type not in the pass-through list |

### Design: Content-Type-Driven Blob Detection

The tool executor checks `ResponseContentType` after each dispatcher call:

- **Pass-through types** (`text/*`, `application/json`, `application/xml`) → return the text directly to the model
- **Binary types** (everything else) → encode the response blob to base64, store it in the
  blob store, and return a JSON object with a reference token and metadata instead

No auto-detection of base64 patterns in JSON. No scanning of text responses.
The content type is the single source of truth.

### Reference Tokens

**On response (binary tool result → model):**
- Executor gets a binary response (content type is not `text/*`)
- Encodes to base64, stores in blob store with a GUID key
- Returns to model: `{ "blobRef": "{{blob:<guid>}}", "size": 204800, "contentType": "application/pdf" }`
- Model sees a small JSON object, not the binary data

**On request (model → tool):**
- Model passes `{{blob:<guid>}}` in a tool argument value (e.g. inside `data` JSON)
- Tool server scans the argument string for `{{blob:*}}` patterns and resolves them to
  actual base64 data before dispatching
- If the reference is invalid/expired, returns an error

### Example Flow

```
1. Model calls: invoke_message_type({ type: "Sales.Invoice.GetPdf", subject: "INV-001" })
2. Dispatcher returns binary PDF (content type: application/pdf)
3. Executor encodes to base64, stores in blob store, returns to model:
   { "blobRef": "{{blob:a1b2c3d4}}", "size": 204800, "contentType": "application/pdf" }
4. Model calls: invoke_message_type({ type: "Incoming.Document.Create",
     data: "{ \"content\": \"{{blob:a1b2c3d4}}\" }" })
5. Tool server resolves {{blob:a1b2c3d4}} → actual base64 in the data string, dispatches
```

### Implementation in `MCP Tool Server ori`

```al
var
    BlobStore: Dictionary of [Text, Text];       // guid → base64 value
    BlobContentTypes: Dictionary of [Text, Text]; // guid → contentType
    BlobSizes: Dictionary of [Text, Integer];     // guid → byte size

procedure StoreBlob(Base64Value: Text; ContentType: Text; ByteSize: Integer): Text  // returns {{blob:<guid>}}
procedure ResolveBlob(Reference: Text): Text                     // returns base64 or error
procedure ResolveBlobsInText(var InputText: Text)                // replaces all {{blob:*}} in a string
procedure ClearBlobStore()                                       // called on session reset
```

The blob store is **not a tool** — it's internal plumbing in the executor/server. The model never
calls blob store procedures directly. It only sees references in tool results and passes them in
tool arguments.

### `encode_base64` / `decode_base64` — Removed

Replaced by `set_blob` / `get_blob` which are more general purpose.
`set_blob` can store any content (text or base64). `get_blob` retrieves it.
Base64 encoding/decoding of binary dispatcher responses is handled automatically
by the executor (content-type driven), not by explicit tools.

### Rules

- **Content-type driven**: Only binary (non-pass-through) responses are blob-stored. Pass-through types (`text/*`, `application/json`, `application/xml`) are returned directly.
- **UTF-8 everywhere**: All text ↔ stream conversions use `TextEncoding::UTF8`. This applies to the executor reading dispatcher responses, blob store read/write, and request payload construction.
- **Lifetime**: Blobs live for the duration of the SingleInstance (chat session). Cleared on `ResetSession()`.
- **No persistence**: Blobs are never written to the database — purely in-memory for the conversation.
- **Reference format**: `{{blob:<guid>}}` — easily regex-matchable, unlikely to collide with real data.
- **Resolution**: `ResolveBlobsInText` scans the input string for `{{blob:*}}` patterns and replaces all of them before dispatching.
- **Memory cap**: If total stored blobs exceed a configurable limit (e.g. 50MB), oldest blobs are evicted with a warning in the next tool response.

### Bootstrap Prompt Instruction

The blob handling instructions are included in the BLOB HANDLING section of the
bootstrap system prompt (see Bootstrap System Prompt Template below). They cover:
- What blob references are and how to recognize them
- How to pass them between tools
- When to use `storeJsonPaths` for large responses
- How to use `get_blob`, `set_blob`, `list_blobs`, `delete_blobs`

---

## Tool Catalog (Lite Mode — 16 tools)

All tools route through `Dispatcher ori`. The model uses `invoke_message_type` + `get_message_type_help` for anything not in this list.

### Core Message Type Tools (3)

| Tool Name | Message Type | Description |
|-----------|-------------|-------------|
| `invoke_message_type` | (any — pass-through) | Universal tool — calls any registered message type |
| `list_message_types` | `Help.MessageTypes.Get` (with `OnlyEnabled=true`) | Lists enabled message types only |
| `get_message_type_help` | `Help.Implementation.Get` | Detailed help for a specific message type |

#### `invoke_message_type` — Input Schema

```json
{
  "type": "object",
  "properties": {
    "type": { "type": "string", "description": "Bifrost message type (e.g. 'Sales.Order.Post')" },
    "data": { "type": ["string", "object"], "description": "Payload — string or JSON object. May contain {{blob:<guid>}} references that are resolved before dispatch." },
    "subject": { "type": "string", "description": "Optional subject field" },
    "storeJsonPaths": { "type": "array", "items": { "type": "string" }, "description": "JSON paths in the response to store in blob storage and replace with {{blob:<guid>}} references. Use when the response contains large data you need to forward to another tool without reading it. Example: ['$.records']" }
  },
  "required": ["type"]
}
```

#### `storeJsonPaths` — Selective Blob Storage

When `storeJsonPaths` is provided, the tool server:
1. Executes the message type normally
2. For each JSON path: extracts the value, serializes it, stores in blob store
3. Replaces the value in-place with `{{blob:<guid>}}`
4. Appends `_blobs` metadata array to the response

Example:
```json
// Request
{ "type": "Data.Records.Get", "data": "...", "storeJsonPaths": ["$.records"] }

// Response (model sees)
{
  "noOfRecords": 5000,
  "records": "{{blob:a1b2c3d4}}",
  "_blobs": [{ "ref": "{{blob:a1b2c3d4}}", "jsonPath": "$.records", "size": 2400000, "type": "array", "count": 5000 }]
}
```

This also works on `get_records`, `batch_records`, and other named tools — they all accept `storeJsonPaths`.

#### `list_message_types` — OnlyEnabled Filter

When listing tools, the tool server passes `OnlyEnabled=true` to `Help.MessageTypes.Get`.
This ensures only message types explicitly enabled by the administrator are exposed to the chat model.
Message types with `Enabled = false` are invisible to the AI.

### Identity (1)

| Tool Name | Message Type |
|-----------|-------------|
| `who_am_i` | `Help.WhoAmI.Get` |

### Records (4)

| Tool Name | Message Type |
|-----------|-------------|
| `get_records` | `Data.Records.Get` |
| `set_records` | `Data.Records.Set` |
| `get_record_ids` | `Data.RecordIds.Get` |
| `batch_records` | `Data.Records.Batch` |

### Blob Tools (4)

| Tool Name | Description |
|-----------|-------------|
| `get_blob` | Reads a blob reference and returns its content. For text blobs returns the text directly. For binary blobs returns base64. |
| `set_blob` | Stores a value (text or base64) in the blob store and returns a `{{blob:<guid>}}` reference. |
| `list_blobs` | Lists all blob references in the current session with metadata (size, contentType, created). |
| `delete_blobs` | Deletes one or more blob references to free memory. |

#### `get_blob` — Input Schema

```json
{
  "type": "object",
  "properties": {
    "ref": { "type": "string", "description": "Blob reference ({{blob:<guid>}}) to read." },
    "maxChars": { "type": "integer", "description": "Max characters to return (default 20000). Truncates with a warning if exceeded." }
  },
  "required": ["ref"]
}
```

#### `set_blob` — Input Schema

```json
{
  "type": "object",
  "properties": {
    "content": { "type": "string", "description": "Text or base64 content to store." },
    "contentType": { "type": "string", "description": "MIME type (e.g. 'application/pdf', 'text/json'). Default: 'text/plain'." }
  },
  "required": ["content"]
}
```

Returns: `{ "ref": "{{blob:<guid>}}", "size": 12345, "contentType": "text/json" }`

#### `list_blobs` — Input Schema

```json
{
  "type": "object",
  "properties": {}
}
```

Returns: `{ "blobs": [{ "ref": "{{blob:<guid>}}", "size": 204800, "contentType": "application/pdf" }, ...], "totalSize": 500000 }`

#### `delete_blobs` — Input Schema

```json
{
  "type": "object",
  "properties": {
    "refs": { "type": "array", "items": { "type": "string" }, "description": "Blob references to delete. Pass ['*'] to clear all." }
  },
  "required": ["refs"]
}
```

Returns: `{ "deleted": 3, "remainingSize": 100000 }`

### Memory (4)

| Tool Name | Message Type |
|-----------|-------------|
| `get_user_memory` | `Memory.User.Get` |
| `set_user_memory` | `Memory.User.Set` |
| `get_company_memory` | `Memory.Company.Get` |
| `set_company_memory` | `Memory.Company.Set` |

**Schemas for named tools:** The data tools (`get_records`, `set_records`, `get_record_ids`, `batch_records`)
and memory tools mirror their message type's request format. Use `get_message_type_help` with the
message type name (e.g. `Data.Records.Get`) to get the exact schema. All named tools also accept
the optional `storeJsonPaths` parameter described under `invoke_message_type`.

### Not Included (handled by `invoke_message_type`)

- Table metadata (`Help.Tables.Get`, `Help.Fields.Get`, etc.)
- Search (model constructs `Data.Records.Get` with `@*query*` filters)
- Totals (`Data.Totals.Get`)
- Aging & period analysis (`Analysis.CustomerAging.Get`, `Analysis.VendorAging.Get`, `Analysis.PeriodBreakdown.Get`)
- Translations, timestamps, incoming documents
- BC business events
- Queue operations (not supported — synchronous task only)
- `encrypt_data` (security-sensitive, denylisted)
- `get_cloud_events_api_skill` (large payload, model can use `invoke_message_type` with `Help.Skill.Get` if needed)
- `get_config` / `set_config` (environment-level config, not needed for chat)

---

## Impact on Existing Code

### `AnthropicChatProxy` (Anthropic app)

```al
SystemPrompt := MCPToolServer.Bootstrap(RecordContext);
MCPToolServer.ListTools(McpTools);
// ... in tool loop:
MCPToolServer.CallTool(Name, Args, ...);
```

### `AnthropicToolRunner` (Anthropic app)

Currently builds a limited tool set from explicit message type names. With `MCP Tool Server ori`:
- It can either continue as-is (for curated tool sets) or delegate to the tool server
- No breaking change needed
- Could be refactored to use `MCP Tool Server ori.CallTool('invoke_message_type', ...)` internally

---

## Implementation Phases

### Phase 1: `MCP Tool Executor ori` (core app)

Move the executor pattern from `AnthropicToolExecutor` into the core app.

**Files:** `app/src/BifrostChat/CEMCPToolExecutor.Codeunit.al`

### Phase 2: `MCP Tool Server ori` — Bootstrap + invoke_message_type

Implement the core codeunit with:
- `Bootstrap()` — runs the 4-step sequence, returns system prompt
- `ListTools()` — returns the ~16 tool definitions
- `CallTool()` — dispatches by tool name
- `list_message_types` passes `OnlyEnabled=true` to only expose administrator-enabled types
- Start with just `invoke_message_type`, `list_message_types`, `get_message_type_help`, `who_am_i`

**Files:** `app/src/BifrostChat/CEMCPToolServer.Codeunit.al`

### Phase 3: Remaining Tools

Add the data tools (`get_records`, `set_records`, `get_record_ids`, `batch_records`), memory, blob tools (`get_blob`, `set_blob`, `list_blobs`, `delete_blobs`), and `storeJsonPaths` support.

### Phase 4: Provider Switch

Update `AnthropicChatProxy` to use `MCP Tool Server ori`.

---

## Commit Behavior

All tool calls go through the dispatcher with **default commit behavior** (OmitCommit is never set to true).
This means every tool call exercises the full dispatcher pipeline including queue entry persistence.
The dispatcher handles commits internally — no special handling needed from the tool server.

The model is instructed to ask for user confirmation before calling write operations.
This is enforced at the prompt level, not the code level.

---

## Bootstrap System Prompt Template

```text
You are a Business Central assistant. You can use Bifrost tools to answer
questions with live data and perform actions in the user's BC environment.

RULES:
1. Use tools whenever the answer depends on live BC data or metadata.
2. Prefer read operations before write operations.
3. Before calling any write tool (set_records, batch_records, or invoke_message_type
   for posting/approval), explain what will change and ask the user for confirmation.
4. Keep answers concise and business-facing unless the user asks for technical detail.
5. If a tool fails, say what failed in plain language.
6. Do not mention secrets, credentials, or internal configuration values.

BLOB HANDLING:
- When a tool returns binary data (PDFs, images, files), you receive a blob reference
  like {{blob:<guid>}} with metadata (size, contentType) instead of the raw data.
- Pass blob references directly to other tools that accept binary input — the server
  resolves them automatically. Example: receive a PDF blob ref from one tool, pass it
  to Incoming.Document.Create in the next call.
- Never try to decode, display, or fabricate blob references.
- When calling invoke_message_type and expecting a large response (many records, big
  documents), use storeJsonPaths to specify which JSON paths should be stored as blob
  references instead of returned inline. Example:
  invoke_message_type({ type: "Data.Records.Get", data: "...", storeJsonPaths: ["$.records"] })
  This keeps your context small. You can pass the blob reference to the next tool, or
  use get_blob to inspect it (with maxChars to limit size).
- Use set_blob to store large text you want to forward to another tool without it
  filling your context.
- Use list_blobs to see what's stored. Use delete_blobs to free memory when done.

IDENTITY:
{who_am_i JSON}

LANGUAGE: Reply in {language name from who_am_i}.

{admin system prompt if any}

MEMORY AVAILABLE:
{user memory descriptions}
{company memory descriptions}

API PRIMER:
{Help.Bifrost.Get response}
{Help.Implementation.Get response for Help.Bifrost.Get}

{record context if viewing a specific record}
```

---

## Risks

| Risk | Mitigation |
|------|-----------|
| Bootstrap adds latency at session start (4 dispatcher calls) | All are fast in-process calls (~5ms each); total ~20ms |
| Some message types may not exist in the installed app version | `invoke_message_type` gracefully returns an error if enum value is invalid |
| Tool result too large for model context | Truncate at 20KB; blob store handles large base64 via references |
| SingleInstance state stale across company switches | `Bootstrap()` can be called again to refresh; provider calls it on company change |
| Disabled message types called via invoke_message_type | OnlyEnabled on list_message_types hides them from discovery; direct calls still work but model won't know about them |

---

## Success Criteria

1. `MCP Tool Server ori.Bootstrap()` returns a well-formed system prompt in < 100ms
2. `MCP Tool Server ori.ListTools()` returns 16 tool definitions with correct schemas
3. `MCP Tool Server ori.CallTool('invoke_message_type', { type: 'Data.Records.Get', ... })` returns correct data
4. `list_message_types` only returns message types with `Enabled = true`
5. Blob store correctly replaces large base64 with references and resolves them on input
6. Response time per tool call < 50ms

---

## Object IDs Needed

| Codeunit | ID | Notes |
|----------|----|-------|
| `MCP Tool Server ori` | TBD | Check highest used in range |
| `MCP Tool Executor ori` | TBD | |

Check existing usage in `app.json` or scan `src/` for the next available IDs in 10077885–10078384.
