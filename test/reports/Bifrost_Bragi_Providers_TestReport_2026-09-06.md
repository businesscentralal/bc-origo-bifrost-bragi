# Bifrost Bragi — Chat Providers Migration Test Report

**Date:** 2026-09-06
**Scope:** Migration of the six external chat providers (OpenAI, Azure OpenAI, Custom LLM, Anthropic, xAI, Google/Gemini) from the standalone *Origo Cloud Events Chat* app into Bifrost Bragi.
**Branch:** `feature/bragi-chat-providers` (from `feature/bragi-chat-module`)

## Build

- `alc.exe` (AL 17.0.34.45391) with CodeCop + UICop + AppSourceCop on `app/`: **0 errors, 0 warnings.**
- `alc.exe` with CodeCop + UICop on `test/`: **0 errors, 0 warnings.**
- Residual brand scan (`Cloud Event`, `\bCE\b`, `CE-`, `MCP Chat`) over all new/edited files: no residuals except the intentional references to the legacy app being replaced (data take-over codeunit and its doc comments).
- Object name length check (≤30 chars for app objects, ≤20 for permission sets): all pass.
- Translation: `Bifrost Bragi.is-IS.xlf` realigned against the freshly compiled `.g.xlf` — 253/253 units translated (54 new units added, seeded from the `Comment = 'is-IS=...'` already embedded in every new AL label), 0 `needs-translation` remaining.

## Deploy

| Step | bc28-is (f068155f0c39dev) | bc28-w1 (f089d7daffb9dev) |
|---|---|---|
| Publish `Origo_Bifrost Bragi_28.0.0.0.app` (ForceSync) | OK 200 | OK 200 |
| Publish `Origo_Bifrost Bragi - Tests_28.0.0.0.app` (Synchronize) | OK 200 | OK 200 |

## Unit tests

Both containers: **150 tests, 150 passed, 0 failed** (`Run-BifrostTests.ps1`, 2026-09-06 00:30, results in `TestResults/bragi_is.xml` and `TestResults/bragi_w1.xml`). The first run of the day was 149 tests with 1 failure; see "Resolved failure" below.

New test codeunits (34 tests): `LangModel Prov Base Tests` (17), `LangModel API Client Tests` (5), `LangModel Providers Tests` (7), `Chat Svc Gate Tests` (5). All 116 pre-existing Bragi tests still pass unchanged.

### Resolved failure (both containers, same cause)

`Chat Svc Gate Tests.ChatSvcGate_WritePermission_WithRestrictivePermissions` initially failed because it asserted that the *container's* test user already held `BIFROST ChatSvc ori`. Assigning the set to the user through `Access Control` did not help: under `TestPermissions::Restrictive` the test runner's permission mock decides, not the user's assignments. The test now grants the set itself with `Library - Lower Permissions` (`SetO365Basic` + `AddPermissionSet('BIFROST ChatSvc ori')`), and a new test `ChatSvcGate_WritePermission_WithoutPermissionSet` proves the gate denies a user without it. No container setup is required any more.

## MCP smoke test (bc28-is, CRONUS IS)

Per-provider language models created with the `BIFT-C` prefix (no API key configured, so `IsConfigured` is expected to be `false` and the call must fail cleanly):

| Language Model | Provider | `LLM.Prompt.Complete` result |
|---|---|---|
| `BIFT-C-OAI` | OpenAI | Clean error: *"No chat provider configured. Set up a Bifrost Language Model with a Chat Provider."* |
| `BIFT-C-AZO` | Azure OpenAI | Same clean error |
| `BIFT-C-CUS` | Custom LLM | Same clean error |
| `BIFT-C-ANT` | Anthropic | Same clean error |
| `BIFT-C-XAI` | xAI (Grok) | Same clean error |
| `BIFT-C-GEM` | Google (Gemini) | Same clean error |

No HTTP 5xx, no unhandled exception, no stack trace leaked to the caller for any of the six providers — every call returned a `status: Error` response with the expected message, confirming the enum registration (`Bifrost LangModel Prov. ori` values 2-7), the `OnValidate` default-seeding on the `Chat Provider` field, and the `Bifrost Chat Mgt ori` → provider `Execute(IsConfigured)` → `LLM Prompt Compl Impl ori` dispatch chain all work end-to-end for every migrated provider.

`ChangeLog Write Guard` was opened via `Test.Setup.Set` before creating the six language models and restored to `Blocked` immediately after the smoke test. The six `BIFT-C-*` language models are left in CRONUS IS as a standing smoke-test fixture, consistent with the `BIFT-<letter>` test-data convention.

Testing the actual HTTP call path (`SendToEndpoint` / `Anthropic LangModel Proxy ori`) with a real or invalid API key was out of scope for this pass — the legacy app's own test suite did not exercise that path either (no HTTP-mocking hook exists on the endpoint-explicit send methods, only on the unused role-resolving convenience methods that were not migrated — see "Not migrated" below).

## Data take-over

The legacy *Origo Cloud Events Chat* app's only persistent table, `CE Chat Service Gate ori` (table 10035495), is a permission gate that has never stored any rows (verified from its own doc comment and the absence of any `Insert()` call across the source). `Chat Providers Install ori.TakeOverChatProviderData()`, called from `Copilot Install ori.OnInstallAppPerCompany`, was written and compiled to the pattern used by every other Bifrost replacement app (`TableMetadata.Get` existence check, `DataTransfer` copy on identical field numbers, `UpdateAuditFields(false)`, telemetry log) even though it copies zero rows in practice. Verified live on bc28-is: `TableMetadata.Get(10035495)` — the legacy app **is not installed** in CRONUS IS, so the take-over short-circuits (no-op) as designed; re-installing the app after this change did not produce any errors.

## Not migrated (deliberate)

- **Setup Wizard** (`CE Chat Setup Wizard ori` page + `CE Chat Wizard Reg. ori`): superseded by Bragi's existing Bifrost Language Model Card/List and User Setup Editor, which configure providers per language model rather than through a single global wizard tied to one shared key.
- **`CE Chat Tool Runner ori`**: dead code in the legacy app — grepping the legacy source confirmed no provider, page, or message type ever called it; its only references were its own file, a permission grant, and an xlf comment.
- **`CE Chat Full`/`CE Chat Read` permission set extensions** (bundling chat objects into the Full/Read Access sets): Bragi's own `BIFROST Chat ori` doc comment already states the design choice to keep chat "deliberately not bundled into any other set" — carrying these extensions over would have silently reversed that decision.

## Follow-ups

1. When a real API key becomes available for any provider, extend the smoke test to exercise the actual HTTP call path.
2. Consider registering `LangModel Chat Proxy ori` / `LangModel API Client ori`'s `SendToEndpoint` with an `OnBeforeSendRequest`-style integration event (mirroring the legacy `CE Chat API Client ori` pattern, but on the path providers actually use) if HTTP-level unit testing is wanted in a future story.
