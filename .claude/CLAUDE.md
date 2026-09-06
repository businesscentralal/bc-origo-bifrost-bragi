# Extension: Bifrost Bragi

## Prefix
(none - objects use raw names with the mandatory `ori` suffix inside the `Origo.Bifrost.Bragi` namespace)

## Namespace
Origo.Bifrost.Bragi (tests: Origo.Bifrost.Bragi.Test)

Every file that touches a Bifrost Foundation object also declares `using Origo.Bifrost;`.

## Object ID Range
App:   10035335-10035484 (see `origo_cloudevents_object_ranges.xlsx`)
Tests: 96000-96199

## Target BC Version
28.x (application/platform 28.0.0.0, runtime 17.0)

## Source Control
Platform: GitHub
Organization: businesscentralal
Repository: bc-origo-bifrost-bragi
Default branch: main

## Dependencies
- Bifrost Foundation 28.0.0.0 (`7505e808-6e52-4b96-a328-82573391297a`)

## Naming Rules
- Every object carries the `ori` suffix (AppSource mandatory affix) and is at most 30 characters.
- Permission set object names are at most 20 characters (`BIFROST Bragi ori`, `BIFROST Bragi Rd ori`, `BIFROST Chat ori`).
- The brand name "Bifrost" lives in the namespace, the app name and user-facing captions - never as an object-name prefix. Exception: the chat feature is a product name, "Bifrost Chat" (objects `Bifrost Chat ... ori`, folder `app/src/BifrostChat`, Icelandic "Spjalla við Bifröst").
- The chat "role" concept is the **Language Model**: table `Bifrost Language Model ori`, sub-objects `Bifrost LangModel ... ori` (Card, List, Prov., Provider, None, Test Ctx - `LangModel` keeps them within 30 characters), User Setup field `Bifrost Language Model Code`, Icelandic "mállíkan". The JSON request key `roleCode` stays (API contract).
- "MCP Tool Server" keeps its protocol name (Model Context Protocol).
- Icelandic captions use "Bifröst".

## What Bragi extends in Bifrost Foundation
Foundation owns the extension points; Bragi supplies the values. Never ask for a change in Foundation
that Bragi can make itself through an extension object.

| Foundation object | Bragi extension |
| --- | --- |
| enum `Message Type ori` | `Bragi Message Type ori` - value `LLM.Prompt.Complete` |
| enum `Request Log Type ori` | `Bragi Request Log Type ori` - values `Copilot` and `LLM` + maskers |
| table `User Setup ori` | `User Setup Bragi ori` - field `Bifrost Language Model Code` |
| page `User Setup Editor ori` | `User Setup Editor Bragi ori` - field + Bifrost Chat FactBox |
| page `Setup ori` | `Setup Bragi ori` - **one** action `BragiSetup` (opens `Bragi Setup ori`) + actionref in `Category_Apps` |
| codeunit `Secret Store ori` | `Bragi Secrets ori` - registers and resolves the language model API keys |

Foundation's `Help WhoAmI Get Impl ori` is `Access = Internal` and cannot be called from Bragi.
Use `Bifrost Chat Utils ori.GetIdentityJson()`, which runs the public `Help.WhoAmI.Get` message type
through `Msg Interface ori` instead.

## Chat Providers
Six external providers (Copilot is native to Bragi) live under `app/src/Providers/<Provider>/`, registered
as values on the base enum `Bifrost LangModel Prov. ori` (2-7): `OpenAI LangModel Prov. ori`,
`Azure OAI LangModel Prov. ori`, `Custom LLM LangModel Prov. ori`, `Anthropic LangModel Prov. ori`
(+ `Anthropic LangModel Proxy ori` for its own Messages API), `xAI LangModel Prov. ori`,
`Gemini LangModel Prov. ori`. They were migrated from the standalone *Origo Cloud Events Chat* app
(businesscentralal/origo-bc-cloudevents-chat), which Bragi replaces - see CHANGELOG 28.0.0.0 for the full
rename table and the `Chat Providers Install ori` data take-over.
Shared infrastructure lives in `app/src/Providers/Shared/`: `LangModel Prov. Base ori`,
`LangModel API Client ori`, `LangModel Chat Proxy ori`, table `Chat Svc Gate ori` (shared-key permission
gate, permission set `BIFROST ChatSvc ori`), `Chat Http Notif. Action ori`, `LLM Req Log Masker ori`.
Object ids 10035406-10035420 are used by the providers; 10035421 (`Bragi Setup ori`) and 10035422
(`Bragi Secrets ori`) by the setup/secret block. **The free range is 10035423-10035484** (an earlier note
in this file claimed 10035422 was the next free id - that was wrong, 10035421 was free too and is now used).
Test ids used: 96000-96014; free test ids: 96015-96199.

## Setup Page and Secrets (Bifrost Foundation platform rules)

- **Setup**: `Setup Bragi ori` (pageextension 10035403) contains **only** `addlast(Apps)` with the
  `BragiSetup` action and `addlast(Category_Apps)` with its actionref - no fields, no other groups, no
  trigger. Everything else lives on `Bragi Setup ori` (page 10035421, help slug `bragi-setup`), which
  shows the language models, the MCP tool count and the missing API keys, opens **Bifrost App Secrets**
  filtered to Bragi, and carries the HttpClient notification in `OnOpenPage`.
- **Secrets**: Bragi never touches IsolatedStorage. `Bragi Secrets ori` (codeunit 10035422) wraps
  Foundation's `Secret Store ori`. Codes per language model:

  | Secret code | Scope | Purpose |
  | --- | --- | --- |
  | `LANGMODEL-<Code>-API-KEY` | `Company` | shared key for the whole company |
  | `LANGMODEL-<Code>-USER-API-KEY` | `"Company And User"` | personal key of one user |

  `<Code>` is the uppercased language model code. The longest possible secret code is 43 characters
  (10 + `Code[20]` + 13), so a model code is never truncated.
- Both codes are registered on insert and rename of a language model, and from
  `Copilot Install ori.OnInstallAppPerCompany` / `Copilot Upgrade ori.OnUpgradePerCompany` for every
  existing model. `Register` is idempotent. `OnDelete` clears both values.
- Reads go through `Bragi Secrets ori.TryGetApiKey` (personal key first, then shared, both with
  `MarkUsed`). Values are `SecretText` all the way into the HTTP header - `SecretText.Unwrap()` is
  `OnPrem`-scoped and must never be used here. The chat control add-in's `apiKey` config property is a
  non-secret marker (`Bifrost Chat Argument ori.GetApiKeyIndicator()`); the JavaScript only tests it for
  truthiness and routes every request back through AL.
- Secret **values never migrate** between extensions. Administrators re-enter the shared key once per
  language model and users re-enter their personal key once. Renaming a model leaves the old
  registration rows behind with no value - `Secret Store ori` has no unregister operation.

## Documentation

Documentation lives in businesscentralal/bifrost (site bifrost.origo.is); no Help/ or docs/ folders in
this repo - deviation from the Origo PR gateway check 8 approved by the user 2026-09-06.

- Product documentation: https://bifrost.origo.is/en-us/bragi/ (`docs/bragi/` in the site repository)
- In-product help: https://bifrost.origo.is/en-us/help/bragi/ (`help/bragi/`)
- `app.json` points at those URLs through `help` and `contextSensitiveHelpUrl`; `ContextSensitiveHelpPage`
  on every page and page extension carries the Docusaurus slug (`bragi-setup`,
  `bifrost-chat`, `bifrost-lang-model-card`, `bifrost-lang-model-list`), not an HTML file name. When you add a page,
  add the matching `help/bragi/<slug>.md` in the site repository - and its Icelandic translation under
  `i18n/is-IS/docusaurus-plugin-content-docs-help-bragi/current/`.

## Development Standards

This project follows the **Origo BC Development Standards** (https://github.com/OrigoSoftwareSolutions/bc-dev-standards).

Before writing any AL code, load the relevant skills:
- **`origo-bc-al-coding-standards`** - namespaces, XML docs, naming, formatting, performance, enums, Format/Evaluate, events, error handling, JSON, security
- **`origo-bc-test-writer`** - test structure, AAA pattern, coverage checklists, mock patterns
- **`origo-bc-documentation-writer`** - XML doc comments, markdown reference docs, help codeunits, sync rules

Key rules always in effect:
- Namespace on line 1 of every file
- XML documentation on every object and non-local procedure
- Bilingual captions (`Comment = 'is-IS=...'`) on all user-facing text
- `SetLoadFields` on all record reads
- `Format(guid, 0, 4)` for GUIDs, `Format(value, 0, 9)` / `Evaluate(var, text, 9)` for culture-invariant serialization
- Never use `Format()` / `Evaluate()` on enum values - use `.Names()`, `.Ordinals()`, `.AsInteger()`, `.FromInteger()`
- One statement per line, no `WITH`
- Implementation = code + tests + documentation (help codeunit, markdown docs, HTML help)

## Development Environment
- Two COSMO Alpaca containers, both defined in `app/.vscode/launch.json` (git-ignored, the authority for
  instance ids): `launch: bc28-is` (Icelandic CRONUS IS, used for the MCP message-type tests) and
  `launch: bc28-w1` (W1 CRONUS International Ltd.). Publish and run the unit tests on **both**; select the
  target with `-LaunchConfiguration 'launch: bc28-w1'`.
- Compile locally with alc.exe + CodeCop/UICop/AppSourceCop, zero errors and zero warnings.
  Symbols: `app/.alpackages` (Microsoft symbols + the current `Origo_Bifrost Foundation_28.0.0.0.app`),
  `test/.alpackages` (Microsoft test libraries + Foundation + the freshly built Bragi app).
- Publish and test without VS Code (pwsh 7, credential from the user-level env vars `BC28IS_USER` /
  `BC28IS_PASSWORD`, never from files) with the Foundation tooling:
  `bc-origo-bifrost-core/tools/Publish-BifrostApp.ps1 -AppFile <.app>` (ForceSync for the app,
  Synchronize for the test app) and `bc-origo-bifrost-core/tools/Run-BifrostTests.ps1
  -TestAppJson test/app.json -ResultsFile TestResults/bragi_is.xml`.
- The AL test runner drives a web client session on a shared container. When other agents publish to the
  same container at the same time the run can return an empty result file (`Codeunits: 1  Tests:` with no
  numbers). Cause: the Command Line Test Tool returns no tests on the first visit of a suite name that does not
  exist yet. `Run-BifrostTests.ps1` now visits the suite before running; if you pass your own `-TestSuite`, run twice
  or reuse an existing name. Never switch to a fresh name to "retry" - that reproduces the empty run.

## Message Type Conventions
- Bragi owns exactly one message type, `LLM.Prompt.Complete`, registered on Foundation's `Message Type ori`
  enum by `Bragi Message Type ori`. It has an `LLM Prompt Compl Impl ori` codeunit (`ExecuteBifrostTask`),
  an `LLM Prompt Compl Help ori` help codeunit and a section in the message-type reference on
  bifrost.origo.is (`docs/bragi/message-types.md` in the `businesscentralal/bifrost` repository).
- Errors must be returned as `status = Error` with a helpful message via `Argument.RespondWithError`;
  never let an unhandled exception reach the API.

## Testing Through the MCP Server
- `get_message_type_help` and `invoke_message_type` on the `origo-bc-bc28-is` server hit Bragi through
  Foundation's route (`origo/bifrost/v1.0`). Keep calls serial - parallel bursts crash the server.
  Test data uses the `BIFT-<letter>` prefix in CRONUS IS.
