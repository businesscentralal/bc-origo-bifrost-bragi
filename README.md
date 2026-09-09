# Bifrost Language Models

**App name:** Bifrost Language Models (display form *Bifröst mállíkön*)  
**Publisher:** Origo — **Version:** 28.0.0.0 — **Target:** Cloud (BC 28, runtime 17.0)  
**App ID:** `f1722684-0c24-4022-a2e0-0f63154aca76` — **Test app ID:** `9c452c6e-df9b-4eb0-9a54-7ea8f32483ec`  
**Object ID range:** 10035335–10035484 (tests 96000–96199) — **Namespace:** `Origo.Bifrost.LanguageModels`  
**Depends on:** Bifrost Foundation 28.0.0.0  
**Environments:** Business Central online (SaaS) and the COSMO Alpaca development containers `bc28-is` (CRONUS IS) and `bc28-w1` (CRONUS International Ltd.)

---

## Overview

Bifrost Language Models is the chat module of the Bifröst platform. It adds a conversational
assistant to Business Central: the Bifrost Chat control add-in and FactBox, language models that
hold the provider configuration and the skill text, seven chat providers (Copilot, OpenAI, Azure
OpenAI, Custom LLM, Anthropic, xAI and Google/Gemini), an MCP tool server that lets the assistant
read and act on Business Central data under the signed-in user's own permissions, and the
`LLM.Prompt.Complete` message type.

The module was extracted from *Bifrost Foundation* in version 28.0.0.0 and replaces the standalone
*Origo Cloud Events Chat* app. It installs beside Foundation and extends it.

The app never stores an API key itself. Every key lives in Foundation's secret store under this
app's id, addressed by a secret code per language model, and is passed as `SecretText` all the way
into the HTTP header.

---

## Functional Flow

1. **Create a language model.** An administrator opens **Bifröst mállíkön Setup**
   (`LangModel Setup ori`) from the *Apps* group on the Bifröst Setup page, goes to the language
   model list and creates a `Bifrost Language Model ori` row: a code, a description, the chat
   provider, the endpoint fields (`Base URL`, `Model`, `Chat Path`, `Models Path`,
   `Timeout Seconds`, `Max Tokens`) and the skill text that becomes the system instruction.
2. **Store the API key.** On `Bifrost LangModel Card ori` the actions **Set Shared API Key** and
   **Set Personal API Key** write the key through `LangModel Secrets ori` into Foundation's secret
   store. The card only shows read-only *Shared Key Stored* / *Personal Key Stored* flags — the
   value is never displayed or read back into the page. The shared-key actions are gated by
   `BIFROST ChatSvc ori`.
3. **Assign the model to a user.** `User Setup Editor LangMdl ori` adds the field
   **Bifrost Language Model Code** to the Bifröst user setup, so each user gets the skill and
   provider configuration of the model assigned to them, falling back to the default model.
4. **Chat from a record page.** 36 page extensions put `Bifrost Chat FactBox ori` on the customer,
   vendor, item, sales, purchase, ledger entry and incoming document pages. The FactBox passes the
   current record to the control add-in; the **Focus** action opens `Chat Focus ori` with the
   history carried across by `Bifrost Chat Transfer ori`.
5. **Answer with tools.** The provider's tool loop calls `MCP Tool Server ori`, which exposes the
   Bifröst message types as tools. `MCP Tool Executor ori` runs each tool call in its own
   `Codeunit.Run` scope, so a message type that commits or fails cannot corrupt the loop. Every
   call runs under the signed-in user's own permissions.
6. **Call it without a UI.** `LLM.Prompt.Complete` sends a system prompt and a user prompt to the
   configured provider and returns the text, with no tools and no conversation state. It is the
   general-purpose reasoning step for playbooks and scheduled tasks.

---

## Benefits

- **No key in this app.** API keys live in Foundation's secret store, are `SecretText` end to end
  and never reach a table, a caption, telemetry or an error message. There is one place to rotate
  and one place to audit.
- **The user's own permissions.** The MCP tool server calls Business Central as the signed-in user,
  so the assistant can never read or write anything that user could not read or write manually.
- **Seven providers, one contract.** Copilot, OpenAI, Azure OpenAI, Custom LLM, Anthropic, xAI and
  Google/Gemini all implement `Bifrost LangModel Provider ori`; adding another provider is a new
  enum value plus a codeunit, with no change to the chat pages.
- **Chat where the work is.** The FactBox sits on the pages people already use, with the record
  context supplied automatically — no separate assistant window to switch to.
- **Two separate gates.** `BIFROST Chat ori` grants chat execution and `BIFROST ChatSvc ori` grants
  the shared key, so "may chat" and "may manage the company key" are delegated independently.
- **Bilingual and AppSource-ready.** Every caption ships in en-US and is-IS; every object carries
  the registered ` ori` affix.
- **Safe succession.** On first install per company the app takes its data over from the published
  *Origo Cloud Events Chat* app.

---

## Logic Flow

```
BC page (36 page extensions)          caller ─► Bifröst Foundation (Queue → Task → Data)
      │  Bifrost Chat FactBox ori                    │
      │  Chat Focus ori                              ▼
      ▼                                    Message Type ori  (extended by "LangModel Message Type ori")
 "Bifrost Chat Mgt ori"                              │  binds LLM.Prompt.Complete to
      │  resolves the user's language model          ▼
      ▼                                    "LLM Prompt Compl Impl ori" : Msg Interface ori
 "Bifrost Language Model ori"
      │  field "Chat Provider"
      ▼
 enum "Bifrost LangModel Prov. ori"  ──selects──►  interface "Bifrost LangModel Provider ori"
                                                            │
       ┌────────────────────────────────────────────────────┼───────────────────────────────┐
       ▼                                                    ▼                               ▼
 "Copilot LangModel Prov. ori"          OpenAI / Azure OpenAI / Custom LLM     "Anthropic LangModel Prov. ori"
       │  System.AI, no key                 xAI / Gemini providers                          │
       ▼                                                    │                               ▼
 "Copilot Chat Proxy ori"                    "LangModel Prov. Base ori"          "Anthropic LangModel Proxy ori"
       │                                     "LangModel API Client ori"                     │
       │                                     "LangModel Chat Proxy ori"                     │
       └────────────────────────────────────────────────────┼───────────────────────────────┘
                                                            ▼
                                            "MCP Tool Server ori" ──► "MCP Tool Executor ori"
                                                            │             Codeunit.Run per tool call
                                                            ▼
                                            Bifröst message types, run as the signed-in user
```

Supporting paths:

- **Secrets** — `LangModel Secrets ori` is this app's facade over Foundation's `Secret Store ori`.
  Codes are `LANGMODEL-<Code>-API-KEY` (scope *Company*, the shared key) and
  `LANGMODEL-<Code>-USER-API-KEY` (scope *Company And User*, the personal key). A read tries the
  personal key first, then the shared one, both with `MarkUsed`.
- **Permission gates** — `Chat Gate ori` and `Chat Svc Gate ori` store no rows; they exist only as
  `WritePermission()` check targets behind `BIFROST Chat ori` and `BIFROST ChatSvc ori`.
- **Request logging** — `LangModel Req Log Type ori` adds the `Copilot` and `LLM` values to
  Foundation's request log, with `Copilot Req Log Masker ori` and `LLM Req Log Masker ori`
  redacting bodies outside debug mode.
- **Lifecycle** — `Copilot Install ori` registers the Copilot capability per database and, per
  company, registers the secret codes of every existing language model and calls
  `Chat Providers Install ori` for the take-over from the published Cloud Events Chat app.
  `Copilot Upgrade ori` repeats both registrations after an upgrade.
- **Argument transport** — `Bifrost Chat Argument ori` is a temporary table used as the DTO of the
  single-procedure provider interface; `Bifrost Chat Proc. Type ori` says which operation to run,
  so new operations are added as enum values instead of interface methods.

---

## Setup & Configuration

| Step | Where | What |
| --- | --- | --- |
| 1 | Extension Management (page 2500) | Enable **Allow HttpClient Requests** for Bifrost Language Models. Every external provider needs it; the **Bifrost Setup** page shows a notification with a **Start setup wizard** action when it is off for any installed Bifröst app. |
| 2 | **Bifröst Setup** → *Apps* → **Bifröst mállíkön** | Open `LangModel Setup ori` (page 10035421), the single place this module is configured. It reports the number of language models, the default one, the MCP tool count and how many models still need an API key. |
| 3 | `Bifrost LangModel List ori` / `Bifrost LangModel Card ori` | Create one row per language model and fill in the provider and endpoint fields. |
| 4 | `Bifrost LangModel Card ori` actions | **Set / Clear Shared API Key** (needs `BIFROST ChatSvc ori`) and **Set / Clear Personal API Key**. Both use Foundation's shared masked dialog. |
| 5 | `User Setup Editor LangMdl ori` | Assign a language model to each user in **Bifrost Language Model Code**. Users without an assignment get the default model. |

`Bifrost Language Model ori` (table 10035335) fields:

| Field | Purpose |
| --- | --- |
| `Code` | The model code. It is also the `roleCode` in the JSON contract and the `<Code>` part of the secret codes. |
| `Description` | Free text shown in lists and lookups. |
| `Skill` | Markdown blob injected as the system-level instruction for this model. |
| `Default` | The model used by a user who has none assigned. |
| `Chat Provider` | Selects the `Bifrost LangModel Provider ori` implementation; `None` inherits the user-level provider. |
| `Base URL`, `Chat Path`, `Models Path` | Endpoint of the external provider. |
| `Model` | The provider's model identifier. |
| `Timeout Seconds`, `Max Tokens` | Request limits. |

Permissions:

| Set | Grants |
| --- | --- |
| `BIFROST LLM ori` | Full access to the module — but deliberately **not** write access to `Chat Gate ori`. |
| `BIFROST LLM Rd ori` | Read-only access to language models. |
| `BIFROST Chat ori` | The chat itself: the FactBox and Focus page, `LLM.Prompt.Complete`, and execute on every provider codeunit. Must be assigned explicitly on top of one of the two sets above. |
| `BIFROST ChatSvc ori` | View, set and clear the shared (service) API key. Assigned separately so "manage the company key" can be delegated without granting chat. |

API keys do not migrate between extensions. After deployment every language model shows no key
stored: an administrator re-enters the shared key once per model, and each user re-enters their
personal key once.

---

## Example Scenario

An accountant is looking at customer `10000` in Business Central and wants to know why the balance
is higher than last month.

1. The Customer Card opens. `Bifrost Chat CustomerCard ori` shows `Bifrost Chat FactBox ori` and
   passes the record context (table `Customer`, the row's `SystemId`, the caption built from the
   customer number and name) to the control add-in.
2. The accountant types the question. `Bifrost Chat Mgt ori` reads the language model assigned to
   this user in the Bifröst user setup — say `GPT4O`, provider *OpenAI* — resolves the API key
   through `LangModel Secrets ori` (personal key first, then the company key) and builds the
   argument record with the model's skill text as the system instruction.
3. `LangModel Chat Proxy ori` posts the request through `LangModel API Client ori`. The model asks
   for the customer's ledger entries, so the response comes back as `tool_calls`.
4. `MCP Tool Server ori` maps each tool call to a Bifröst message type and `MCP Tool Executor ori`
   runs it in its own `Codeunit.Run` scope, **as the signed-in accountant**. Entries the accountant
   is not allowed to read are not returned — to the assistant either.
5. The tool results go back into the loop and the model writes the answer, which the FactBox
   renders. Clicking **Focus** opens `Chat Focus ori` full screen with the history handed over by
   `Bifrost Chat Transfer ori`.

If the key is missing, the endpoint is unreachable or HttpClient requests are blocked, the chat
shows the reason instead of failing silently, and the same call made through `LLM.Prompt.Complete`
comes back as `status = Error` with a message naming the cause — no exception reaches the API.

---

## Objects

90 objects, all inside range 10035335–10035484. Ids 10035335–10035423 are used, with 10035408 free
again since `Chat Http Notif. Action ori` was removed with the setup notifications; the free range is
**10035424–10035484, plus 10035408**. Every object carries the mandatory ` ori` affix.

### Tables

| ID | Name | Purpose |
| --- | --- | --- |
| 10035335 | `Bifrost Language Model ori` | One row per language model: provider, endpoint, limits and the skill markdown. |
| 10035336 | `Chat Gate ori` | Permission gate for the chat. Stores no rows — a `WritePermission()` target only. |
| 10035337 | `Bifrost Chat Argument ori` | Temporary DTO of the single-procedure provider interface (inputs, outputs, `Procedure Type`). |
| 10035406 | `Chat Svc Gate ori` | Permission gate for the shared (service) API key. Stores no rows. |

### Table extension

| ID | Name | Extends | Purpose |
| --- | --- | --- | --- |
| 10035401 | `User Setup LangModel ori` | `User Setup ori` (Foundation) | Adds the per-user field **Bifrost Language Model Code**. |

### Pages

| ID | Name | Purpose |
| --- | --- | --- |
| 10035341 | `Bifrost Chat FactBox ori` | FactBox hosting the `Bifrost Chat ori` control add-in; provider-neutral, everything goes through `Bifrost Chat Mgt ori`. |
| 10035342 | `Bifrost Chat Model List ori` | Lookup for picking one of the models the provider reports. |
| 10035343 | `Bifrost LangModel Card ori` | Edits one language model, its skill markdown and its four API-key actions. |
| 10035344 | `Bifrost LangModel List ori` | List of language models. |
| 10035345 | `Chat Focus ori` | Full-page chat opened from the FactBox **Focus** action; restores history and record context. |
| 10035421 | `LangModel Setup ori` | The module's own setup page — the only place it is configured. |

### Page extensions

| ID | Name | Extends | Purpose |
| --- | --- | --- | --- |
| 10035346–10035381 | `Bifrost Chat <Page> ori` (36) | Customer Card/List, Vendor Card/List, Item Card/List; the sales and purchase quotes, orders, invoices, credit memos and return orders with their list pages; Bank Account, Customer, Detailed Customer, Vendor, Item, Value, VAT and G/L entries; Incoming Document and Incoming Documents | Each adds `Bifrost Chat FactBox ori` to the page, shows it only when `Bifrost Chat Mgt ori.ShowBifrostChat()` is true, and feeds the current record to it in `OnAfterGetCurrRecord`. All carry `ContextSensitiveHelpPage = 'bifrost-chat'`. |
| 10035402 | `User Setup Editor LangMdl ori` | `User Setup Editor ori` (Foundation) | Adds the language model field and the chat FactBox to the Bifröst user setup editor. |
| 10035403 | `Setup LangModel ori` | `Setup ori` (Foundation) | Adds exactly one *Apps* action opening `LangModel Setup ori`, plus its actionref in `Category_Apps`. |

### Enums

| ID | Name | Purpose |
| --- | --- | --- |
| 10035338 | `Bifrost Chat Proc. Type ori` | Names the operation to run on the provider interface, so new operations need no new interface method. |
| 10035339 | `Bifrost LangModel Prov. ori` | Selects the provider implementation of a language model; `None` inherits the user-level provider. Extensible. |

### Enum extensions

| ID | Name | Extends | Purpose |
| --- | --- | --- | --- |
| 10035340 | `Copilot Capability ori` | `Copilot Capability` (Microsoft) | Registers the Bifrost Chat capability with the Copilot framework. |
| 10035399 | `LangModel Message Type ori` | `Message Type ori` (Foundation) | Adds `LLM.Prompt.Complete`. The caption is the public wire contract. |
| 10035400 | `LangModel Req Log Type ori` | `Request Log Type ori` (Foundation) | Adds the `Copilot` and `LLM` request log types together with their maskers. |

### Interface

| Name | Purpose |
| --- | --- |
| `Bifrost LangModel Provider ori` | Single-procedure contract for every chat provider; `Bifrost Chat Proc. Type ori` on the argument record names the operation. |

### Control add-in

| Name | Purpose |
| --- | --- |
| `Bifrost Chat ori` | Provider-neutral JavaScript chat UI. All configuration arrives through the Initialize ConfigJson payload and every request is routed back through AL. |

### Codeunits

| ID | Name | Purpose |
| --- | --- | --- |
| 10035382 | `Bifrost Chat Mgt ori` | Public entry point: resolves the user's language model and delegates through the provider interface. |
| 10035383 | `Bifrost Chat Transfer ori` | SingleInstance holder of record, caption, skill and message history across the FactBox → Focus transition. |
| 10035384 | `Bifrost LangModel Test Ctx ori` | SingleInstance side channel that hands the card's record context to a provider's TestConnection. |
| 10035385 | `Copilot LangModel Prov. ori` | Copilot provider — System.AI managed resources, no key and no external endpoint. |
| 10035386 | `MCP Tool Executor ori` | Runs one message type in its own `Codeunit.Run` scope; base64-encodes binary responses. |
| 10035387 | `MCP Tool Server ori` | In-process MCP tool server: session bootstrap, tool listing, tool execution and blob storage for large responses. |
| 10035388 | `Bifrost Chat Utils ori` | Message-history budgeting, and `GetIdentityJson()` which runs the public `Help.WhoAmI.Get` message type. |
| 10035389 | `Bifrost LangModel None ori` | Default no-op provider; delegates to the user-level provider selection. |
| 10035390 | `Copilot Install ori` | Install codeunit: Copilot capability per database; secret registration and the legacy take-over per company. |
| 10035391 | `Copilot Upgrade ori` | Repeats the capability and secret registration after an upgrade. |
| 10035392 | `Copilot AOAI Func Impl ori` | Implements `AOAI Function` so MCP tools can be registered with Copilot dynamically. |
| 10035393 | `Copilot Chat Proxy ori` | Copilot agentic tool loop against Azure OpenAI through System.AI. |
| 10035394 | `Copilot Req Log Masker ori` | Masker for Copilot request log entries; logging happens only in debug mode. |
| 10035395 | `Copilot Default Skill ori` | Ships the default skill text of the Copilot language model, kept in sync with the tool server. |
| 10035396 | `LLM Prompt Compl Impl ori` | `LLM.Prompt.Complete` — one-shot completion, no tools and no conversation state. |
| 10035397 | `LLM Prompt Compl Help ori` | Runtime Markdown help contract for `LLM.Prompt.Complete`. |
| 10035409 | `LLM Req Log Masker ori` | Strips API keys from logged LLM requests and redacts bodies outside debug mode. |
| 10035410 | `LangModel Prov. Base ori` | Shared helpers: config resolution, service-key permission check, token-usage parsing, multi-modal message building. |
| 10035411 | `LangModel API Client ori` | Thin HTTP client for the OpenAI-compatible providers: chat completions and model list, with a caller-supplied auth header. |
| 10035412 | `LangModel Chat Proxy ori` | The OpenAI-compatible agentic tool loop against `MCP Tool Server ori`. |
| 10035413 | `OpenAI LangModel Prov. ori` | OpenAI provider (Bearer token). |
| 10035414 | `Azure OAI LangModel Prov. ori` | Azure OpenAI provider (`api-key` header, deployment-specific chat and models paths). |
| 10035415 | `Custom LLM LangModel Prov. ori` | Self-hosted OpenAI-compatible provider (`x-api-key`) — Ollama, vLLM and similar. |
| 10035416 | `Anthropic LangModel Prov. ori` | Anthropic (Claude) provider (`x-api-key` plus `anthropic-version`). |
| 10035417 | `Anthropic LangModel Proxy ori` | Anthropic tool loop over the Messages API, including the `text` / `tool_use` content blocks. |
| 10035418 | `xAI LangModel Prov. ori` | xAI (Grok): chat completions for text, the Responses API for files. |
| 10035419 | `Gemini LangModel Prov. ori` | Google Gemini: OpenAI-compatible chat, native `generateContent` for files, `x-goog-api-key` header. |
| 10035420 | `Chat Providers Install ori` | One-time data take-over from the published *Origo Cloud Events Chat* app. |
| 10035422 | `LangModel Secrets ori` | This app's facade over Foundation's `Secret Store ori`; owns the `LANGMODEL-*` secret codes. |
| 10035423 | `LangModel Registration ori` | One `OnRegisterApps` subscriber that registers this app and its setup page with Foundation's `App Registry ori`. |

### Permission sets

| ID | Name | Purpose |
| --- | --- | --- |
| 10035398 | `BIFROST Chat ori` | The chat gate: FactBox and Focus page, `LLM.Prompt.Complete`, execute on every provider codeunit. Assigned explicitly. |
| 10035404 | `BIFROST LLM ori` | Full access to the module, without write access to `Chat Gate ori`. |
| 10035405 | `BIFROST LLM Rd ori` | Read-only access to language models. |
| 10035407 | `BIFROST ChatSvc ori` | The shared (service) API key gate. Assigned separately from `BIFROST Chat ori`. |

---

## Dependencies

| App | ID | Purpose |
| --- | --- | --- |
| Bifrost Foundation | `7505e808-6e52-4b96-a328-82573391297a` | Origo 28.0.0.0 — the message-type kernel (`Message Type ori`, `Msg Interface ori`, the Queue → Task → Data API route), the secret store (`Secret Store ori`, `App Secrets ori`), the request log, `User Setup ori` and the shared `Setup ori` page. |

`app.json` declares no other dependency. The test app additionally depends on Bifrost Language
Models itself and on Microsoft's test libraries.

`app.json` also declares `keyVaultUrls` (`https://kv-bc-ktahn486.vault.azure.net/`) and
`internalsVisibleTo` the test app *Bifrost Language Models - Tests*
(`9c452c6e-df9b-4eb0-9a54-7ea8f32483ec`), and suppresses **AA0215** and **AS0081** only.

---

## Documentation

All public documentation lives in the [businesscentralal/bifrost](https://github.com/businesscentralal/bifrost)
site repository and is published at <https://businesscentralal.github.io/bifrost>, in English and
Icelandic. There are no `docs/` or `Help/` folders in this repository — an approved deviation from
Origo PR gateway check 8.

| What | Where |
| --- | --- |
| Product documentation (message types, setup, MCP tool server) | <https://businesscentralal.github.io/bifrost/en-us/bragi/> |
| In-product help (context-sensitive help pages, en-US and is-IS) | <https://businesscentralal.github.io/bifrost/en-us/help/bragi/> |
| Adding a chat provider | <https://businesscentralal.github.io/bifrost/en-us/bragi/extensibility/> |
| Building on Bifröst (extensibility guide) | <https://businesscentralal.github.io/bifrost/en-us/extensibility/> |
| Release notes | [CHANGELOG.md](CHANGELOG.md) |

The message-type contract is also served by the app at runtime: `LLM.Prompt.Complete` answers its
own Markdown help through `get_message_type_help` / `Help.Implementation.Get`.

### Context-Sensitive Help

`app.json` declares `contextSensitiveHelpUrl` =
`https://businesscentralal.github.io/bifrost/{0}/help/bragi/` and `supportedLocales`
`["en-US", "is-IS"]`, so every help page must exist in both locales on the site. Pages carry the
Docusaurus **slug**, not an HTML file name.

| Slug | Pages that use it |
| --- | --- |
| `bifrost-chat` | The 36 `Bifrost Chat <Page> ori` page extensions (10035346–10035381) |
| `bifrost-lang-model-card` | `Bifrost LangModel Card ori` |
| `bifrost-lang-model-list` | `Bifrost LangModel List ori` |
| `bragi-setup` | `LangModel Setup ori` |

When you add a page, add the matching `help/bragi/<slug>.md` in the site repository together with
its Icelandic translation under
`i18n/is-IS/docusaurus-plugin-content-docs-help-bragi/current/`.

---

## Repository layout

| Folder | Content |
| --- | --- |
| `app/` | The AppSource app (`Bifrost Language Models`) |
| `app/src/BifrostChat/` | Chat management, control add-in, FactBox, focus page, page extensions |
| `app/src/BifrostChat/LanguageModel/` | `Bifrost Language Model ori` table, Card/List pages, provider enum and interface |
| `app/src/BifrostChat/Copilot/` | Copilot provider, chat proxy, AOAI function, request log masker, install and upgrade |
| `app/src/BifrostChat/Server/` | MCP tool server and tool executor |
| `app/src/BifrostChat/Message Types/` | `LLM.Prompt.Complete` implementation and help codeunit |
| `app/src/Extensions/` | Extensions of Bifrost Foundation objects (enum, table, page) |
| `app/src/Providers/Shared/` | `LangModel Prov. Base ori`, `LangModel API Client ori`, `LangModel Chat Proxy ori`, `Chat Svc Gate ori`, `LLM Req Log Masker ori`, take-over codeunit |
| `app/src/Providers/OpenAI/`, `AzureOpenAI/`, `CustomLLM/`, `Anthropic/`, `xAI/`, `Gemini/` | The six external chat provider codeunits, one folder per provider |
| `app/src/Setup/` | `LangModel Setup ori` page, `LangModel Secrets ori` and `LangModel Registration ori` |
| `app/src/Permission Set/` | `BIFROST LLM ori`, `BIFROST LLM Rd ori`, `BIFROST Chat ori`, `BIFROST ChatSvc ori` |
| `app/Translations/` | Icelandic translation (`Bifrost Language Models.is-IS.xlf`) |
| `test/` | Test app (`Bifrost Language Models - Tests`, object range 96000–96199) |
| `test/reports/` | Internal test reports — not published |
| `.AL-Go/`, `.github/` | AL-Go for GitHub / COSMO Alpaca pipeline configuration |

---

## Development

- Open `al.code-workspace` in VS Code.
- Development containers: COSMO Alpaca `bc28-is` (CRONUS IS) and `bc28-w1` (CRONUS International
  Ltd.), both defined in `app/.vscode/launch.json` — git-ignored and the authority for the
  instance ids. Publish and run the unit tests on **both**; select the target with
  `-LaunchConfiguration 'launch: bc28-w1'`.
- Compile locally with `alc.exe` plus CodeCop, UICop and AppSourceCop. Zero errors and zero
  warnings beyond the suppressions in `app.json` is the bar. Symbols live in `app/.alpackages`
  (Microsoft symbols plus the current Bifrost Foundation `.app`); test symbols in
  `test/.alpackages`.

  ```
  alc.exe /project:app /packagecachepath:app/.alpackages /out:app/output/languagemodels.app ^
          /analyzer:<CodeCop.dll> /analyzer:<UICop.dll> /analyzer:<AppSourceCop.dll>
  ```

- Publish and run the tests without VS Code (pwsh 7, credential from the user-level env vars
  `BC28IS_USER` / `BC28IS_PASSWORD`, never from files):
  `bc-origo-bifrost-core/tools/Publish-BifrostApp.ps1 -AppFile <.app>` and
  `bc-origo-bifrost-core/tools/Run-BifrostTests.ps1 -TestAppJson test/app.json`.
- Command-line `alc` does not raise AS0011 (mandatory affix); AL-Go CI is the gate, so check the
  ` ori` suffix yourself before pushing.
- `app.json` suppresses **AA0215** and **AS0081** only. No other warning is suppressed.
- Standards: [Origo BC Development Standards](https://github.com/OrigoSoftwareSolutions/bc-dev-standards).
  Project rules are in `.claude/CLAUDE.md`.
- Every object carries the mandatory ` ori` suffix; the brand name is carried by the namespace,
  the app name and the captions, never by an object-name prefix. The one exception is the product
  name "Bifrost Chat".

---

© 2026 Origo ehf.

<!-- AUTO-UPDATE-START -->
# COSMO Alpaca AL-Go AppSource App Template

[![Use this template](https://github.com/microsoft/AL-Go/assets/10775043/ca1ecc85-2fd3-4ab5-a866-bd2e7e80259d)](https://github.com/new?template_name=Alpaca-AppSource-Template&template_owner=cosmoconsult)

This template repository can be used for managing AppSource Apps for Business Central.

It is a customized version of the [AL-Go-AppSource](https://github.com/microsoft/AL-Go-AppSource) template and is designed to be used with [COSMO Alpaca](https://cosmoconsult.com/cosmo-alpaca).

> [!NOTE]
> If you created this repository using the GitHub web UI (for example by clicking **Use this template** on GitHub.com) instead of creating it from the COSMO Alpaca VS Code extension, you must initialize it using the [COSMO Alpaca VS Code extension](https://marketplace.visualstudio.com/items?itemName=cosmoconsult.cosmo-alpaca).  To do this, simply right-click on the repository in VS Code and select _Initialize_.

Please go to https://aka.ms/AL-Go and [COSMO Docs](https://docs.cosmoconsult.com/en-us/cloud-service/alpaca) to learn more.
<!-- AUTO-UPDATE-END -->
