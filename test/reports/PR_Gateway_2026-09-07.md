# Origo BC — PR Gateway Report

```
╔══════════════════════════════════════════════════════════════════╗
║           Origo BC — PR Gateway Report                           ║
║           Extension : Bifrost Language Models v28.0.0.0          ║
║           Customer  : Origo (AppSource, Bifröst portfolio)       ║
║           Date      : 2026-09-07 08:30                           ║
║           Tier      : Standard (AppSourceCop.json, no stories/)  ║
║           Branch    : feature/bragi-chat-providers → main        ║
║                       (PR #2 on PR #1; audited combined vs main) ║
╠══════════════════════════════════════════════════════════════════╣
║  LAYER 1 — Automated Script (23 checks)                          ║
║  Files scanned: 90     Passed: 11/23     Failed: 12              ║
║  After agent triage: 28 real findings fixed, 0 open,             ║
║                      278 dismissed as false positives            ║
╠══════════════════════════════════════════════════════════════════╣
║  LAYER 2 — Agent Deep Checks         Result                      ║
╠══════════════════════════════════════════════════════════════════╣
║  1.  AL Compiler                     ✅ Pass  (0 err / 0 warn)   ║
║  2.  Object Naming — Prefix          ✅ Pass                     ║
║  3.  Object ID Ranges                ✅ Pass                     ║
║  4.  SetLoadFields — Exceptions      ✅ Pass                     ║
║  5.  Breaking Change Guard           ⏭ Skip (initial phase)     ║
║  6.  app.json — Semantic             ⚠️ Pass w/ 3 deviations     ║
║  7.  CHANGELOG & README Quality      ✅ Pass (README rebuilt)    ║
║  8.  HTML Help Pages                 ⚠️ Deviation + 2 warnings   ║
║  9.  Documentation Generation        📝 Done                     ║
║  10. Unit Tests                      ✅ Pass  (178/178 × 2)      ║
║  11. Story-Doc Consistency           ⏭ Skip (no stories/)       ║
║  12. Logic Review                    🔍 5 findings (2 fixed)     ║
║  13. What I Couldn't Check           🔍 5 gaps noted             ║
║  14. Role Coverage                   ⚠️ 2 fixed, 3 decisions     ║
║  15. Platform Integration            ⏭ Skip (not standards repo)║
╠══════════════════════════════════════════════════════════════════╣
║  Overall : ✅ 7 passed  ❌ 0 failed  ⚠️ 3 warnings  ⏭ 3 skipped ║
╚══════════════════════════════════════════════════════════════════╝
```

Target branch `main` detected from `.claude/CLAUDE.md` (`Default branch: main`). PR #2 targets
`feature/bragi-chat-module` (PR #1), which targets `main`; this audit compares the combined result
against `main`. `main` carries no `app/src` files at all, so the whole extension is new.

**Security**: 6 findings, no Critical and no High. See the Security section below.

---

## Layer 1 — Automated scan, with agent triage

The script reports 12 failed checks over 306 raw findings. Every finding was read against the
source. The table records what was real and what was dismissed, with the reason.

| Check | Raw | Real | Disposition |
| --- | ---: | ---: | --- |
| `set_load_fields` | 143 | 0 | 139 are `JsonObject.Get` / `JsonArray.Get` / `Dictionary.Get` / `List.Get` / `HttpClient.Get` — not record reads. The 4 genuine record `Get` calls all hit documented exceptions: followed by `Modify`, returned as a `var` record, passed whole to `BuildChatArgument`, or a read of the `Table Metadata` system table. |
| `one_statement_per_line` | 89 | 0 | 57 are `;` separators inside procedure and event **parameter lists**; 32 are single-line enum `value(N; Name) { Caption = '…'; }` declarations. No file has two executable statements on one line. |
| `xml_doc_comments` | 83 | **25** | 17 are a scanner bug — the `///` block exists but `[NonDebuggable]` sits between it and the `procedure` line. 41 are `internal` procedures implementing `Bifrost LangModel Provider ori`, `Request Log Masker ori` or `Msg Interface ori`, documented by the interface. **25 were real and are fixed** (see check 9). |
| `caption_translation` | 46 | 0 | The message-type caption already carries `Locked = true` (wire contract). The 32 `Bifrost Chat Proc. Type ori` captions are literal dispatch procedure names — a developer-facing contract, never rendered. The 13 `Bifrost Chat Argument ori` field captions belong to a `TableType = Temporary` interface buffer with no page binding. |
| `read_isolation` | 17 | **3** | 17 raw collapse to 6 unique sites. Three are write/uniqueness paths where the default isolation is correct (`Copilot Install ori` guard before `Insert`, the `Default` uniqueness `FindFirst`, the take-over guard before `DataTransfer.CopyRows`). **3 read-only probes were real and are fixed.** |
| `page_code_minimal` | 15 | 0 | 14 `PageExt` actions hold two statements (`SetRecordContext` + `Run`); the scanner counts the `var` line as logic. `Bifrost LangModel List ori:68` is 6 statements, every one a delegation to `Copilot Install ori` — see DECISION-6. |
| `modernization` | 11 | 0 | `MOD-JOBQUEUE-001` matched the substring "nas" inside the Icelandic caption `Líkanaslóð`. `MOD-AUTH-001` matched "User Setup", which here is Foundation's own `User Setup ori` table, not legacy NAV authentication. |
| `global_variables` | 4 | 0 | All four are deliberate: `Bifrost Chat Transfer ori` and `MCP Tool Server ori` are `SingleInstance` session objects (blob store, tool registry, prompt cache); `Bifrost Chat Argument ori` carries payloads past field-length limits under an explicit comment; `LangModel API Client ori` buffers the last request for the request log. |
| `format_guid` | 2 | 0 | `Format(ResultJson)` on a `JsonObject`, not a GUID — the `Format(guid, 0, 4)` rule does not apply. (See the hygiene note under check 13.) |
| `try_prefix_convention` | 2 | 0 | `TryGetLanguageModel` and `TryGetApiKey` are Boolean "try to fetch" accessors mirroring base-app `SecretStore.TryGet`, not error-swallowing `[TryFunction]`s — see DECISION-5. |
| `hardcoded_values` | 1 | 0 | `LangModel Setup ori:200` — `Notification.Id` requires a stable literal GUID; this is the documented BC pattern. |
| `confirm_in_page` | 1 | 0 | `Bifrost LangModel List ori:74` uses exactly the pattern the false-positive guard names: `if not Confirm(…) then exit;`. |

Passing outright: `object_naming`, `namespace`, `event_subscriber_placement`, `reserved_var_names`,
`changelog`, `commit_in_loop`, `format_evaluate_enum`, `app_json`, `with_statements`,
`today_vs_workdate`, `data_classification`.

---

## Check 1 — AL Compiler

Both projects compile with **zero errors and zero warnings**, CodeCop + UICop + AppSourceCop on the
app, CodeCop + UICop on the test app, after every fix in this report.

```
Compilation started for project 'Bifrost Language Models' containing '90' files
Compilation started for project 'Bifrost Language Models - Tests' containing '16' files
```

`alc.exe` on the command line does not raise AS0011 (mandatory affix), so affixes were checked by
hand: all 90 objects carry the ` ori` suffix and all are ≤ 30 characters. Test-app objects carry no
suffix — approved deviation.

## Check 2 — Object naming

No prefix is used; objects carry the registered AppSource affix `ori` as a suffix, inside namespace
`Origo.Bifrost.LanguageModels`. Every file name matches the object declared inside it. The
permission set names stay within AL's 20-character object-name cap (`BIFROST LLM ori`,
`BIFROST LLM Rd ori`, `BIFROST Chat ori`, `BIFROST ChatSvc ori`).

## Check 3 — Object ID ranges

| | |
| --- | --- |
| Declared range (`app.json`, `.claude/CLAUDE.md`, registry) | 10035335–10035484 |
| Used | 10035335–10035422, **contiguous, no gaps, no duplicates** |
| Free | 10035423–10035484 (62 ids) |
| Test range | 96000–96199; used 96000–96015 (96015 added by this run), free 96016–96199 |

90 objects: 4 tables, 1 table extension, 6 pages, 38 page extensions, 30 codeunits, 2 enums,
3 enum extensions, 4 permission sets, 1 interface and 1 control add-in (the last two carry no id).

## Check 4 — SetLoadFields

All 143 Layer 1 findings are false positives (see the table above). Two genuine narrowing
opportunities found by hand were taken: `Bifrost Chat Mgt ori.GetLangModelProvider(RoleCode)` now
loads only `Chat Provider`, and the `Default` uniqueness check on `Bifrost Language Model ori` loads
only `Code`.

## Check 5 — Breaking Change Guard — skipped

Profile **appsource** (`app/AppSourceCop.json` has `mandatoryAffixes`, `mandatorySuffix`,
`publisher` and 14 `supportedCountries`). Phase **initial**: `AppSourceCop.json` has no `version`
property, and `main` contains no `app/src` files, so there is no published baseline to break
against. The check auto-skips.

ℹ️ **Note for the second release.** Once 28.0.0.0 ships, add `"version": "28.0.0.0"` to
`AppSourceCop.json` so the compiler can detect breaking changes against it. There is no ruleset file
in the project, so AppSourceCop uses its default actions — acceptable now, worth adding before the
first update.

## Check 6 — app.json: three deviations, everything mandatory present

Correct and verified: `id` `f1722684-0c24-4022-a2e0-0f63154aca76`, `publisher` `Origo`, `version`
`28.0.0.0`, `target` `Cloud`, `application`/`platform` `28.0.0.0`, `runtime` `17.0`, `idRanges`
`10035335–10035484` matching both the registry and every object in the app, `brief`, `description`,
`url`, `privacyStatement`, `logo`, `supportedLocales` `["en-US","is-IS"]`, `internalsVisibleTo`
pointing at the test app, `resourceExposurePolicy` fully locked down, and
`applicationInsightsConnectionString` set (the modern replacement for `applicationInsightsKey`).

- ⚠️ **`EULA` points at the general Origo terms page** (`https://www.origo.is/skilmalar-og-oryggismal`),
  not at an app EULA. The sibling **Bifrost Attachments** points at the *Cloud Events Terms of Use*
  PDF instead, so the portfolio is inconsistent as well as unresolved.
  **Needs a decision before AppSource submission** — publish a Bifröst EULA, or deliberately reuse an
  existing document, and then use the same one across all Bifröst apps.
- ✅ **`help` and `contextSensitiveHelpUrl` use `businesscentralal.github.io`** instead of
  `bifrost.origo.is`. Approved: the DNS record does not exist yet, and the URLs move with the record.
- ℹ️ **`keyVaultUrls` declares `https://kv-bc-ktahn486.vault.azure.net/` but no AL code in this
  repository reads an Azure Key Vault secret.** It is plausibly required by the Copilot
  managed-resource path (`Copilot LangModel Prov. ori:176` and `Copilot Chat Proxy ori:49` both call
  `AzureOpenAI.SetManagedResourceAuthorization`). The vault URL is a public identifier, not a secret.
  **Verify against the Copilot/AppSource registration before submission rather than removing it.**
- ℹ️ Minor: `.claude/CLAUDE.md` does not record the App ID. The project template asks for it; add
  `f1722684-0c24-4022-a2e0-0f63154aca76` so future gateway runs can cross-check `app.json` against it.

## Check 7 — CHANGELOG and README

**7a — CHANGELOG** ✅ `CHANGELOG.md` carries a `## [28.0.0.0]` heading with categorised
Keep-a-Changelog sections (Renamed before release / Added / Changed / Migration), no `[DRAFT]`
marker, user-focused entries naming specific objects. The heading date moved to `2026-09-07` and two
dated subsections were added for this run's fixes (see check 9).

**7b — README** ❌ → ✅ **fixed.** The README was well written but did not follow the mandatory Origo
template: it had Header, Documentation, Repository layout and Development only. Missing: Overview,
Functional Flow, Benefits, Logic Flow, Setup & Configuration, Example Scenario, Objects table and
Dependencies table.

It was rebuilt against the template, keeping every sentence of the existing prose that was still
correct. All ten mandatory sections are now present and in order, followed by the two useful
non-template sections. The **Objects table lists all 90 objects** — cross-checked declaration by
declaration against `app/src`, with the 36 chat page extensions collapsed into one grouped row
(10035346–10035381) and every other object on its own row with a one-line purpose. The Dependencies
table matches `app.json`. Copyright year 2026. The COSMO Alpaca `<!-- AUTO-UPDATE-START -->` block at
the end is byte-identical to the original — AL-Go rewrites it and it must not be touched.

## Check 8 — Help pages: approved deviation, two open dependencies

The repository holds no `Help/` or `docs/` folder — approved deviation (user, 2026-09-06); all
public documentation lives in `businesscentralal/bifrost`. Every `ContextSensitiveHelpPage` slug was
resolved against that site repository:

| Slug | Pages | en-US | is-IS | Site branch |
| --- | --- | :---: | :---: | --- |
| `bifrost-chat` | 36 page extensions | ✅ | ✅ | `main` |
| `bifrost-lang-model-card` | Bifrost LangModel Card ori | ✅ | ✅ | `main` |
| `bifrost-lang-model-list` | Bifrost LangModel List ori | ✅ | ✅ | `main` |
| `bragi-setup` | LangModel Setup ori | ✅ | ✅ | ⚠️ `setup-pattern-help` only |

- ⚠️ **`bragi-setup` is not on the site's `main` branch yet.** Both `help/bragi/bragi-setup.md` and
  `i18n/is-IS/docusaurus-plugin-content-docs-help-bragi/current/bragi-setup.md` exist, but only on
  branch `setup-pattern-help`. Until that branch merges and the site rebuilds, the Help button on the
  new setup page resolves to a 404. **Merge the site branch with — or before — this PR.**
- ⚠️ **The site still calls this app "Bragi".** `apps.ts:28` in `businesscentralal/bifrost` reads
  `{id: 'bragi', title: 'Bragi', appName: 'Bifrost Bragi', wave: 1}`, and the `docs/bragi/` and
  `help/bragi/` folder names and the `bragi-setup` slug carry the old name throughout. The app was
  renamed to **Bifrost Language Models** in commit `74bc4ae`, and the CHANGELOG explicitly records
  that the site slug stays `bragi` "for now" and the `app.json` URLs follow when the site folders are
  renamed. **This is a site-repository change, deliberately out of scope here** — reported, not fixed.
  Renaming the slug later is a coordinated change: `apps.ts`, both content folders, both i18n
  folders, `ContextSensitiveHelpPage` on four pages, and `help`/`contextSensitiveHelpUrl` in
  `app.json`.

## Check 9 — Documentation

- **XML doc comments** — 25 public procedures had none and now do: the 16 large-text accessors on
  `Bifrost Chat Argument ori` (Skill, UserPrompt, Payload, ConversationState, ToolResults, ResultText,
  ErrorMessage, plus `GetModels`/`SetModels`), the 5 public procedures on `MCP Tool Server ori`
  (`Bootstrap`, `ListTools`, `CallTool`, `GetToolCount`, `ClearSession`), 3 on
  `Bifrost Chat Utils ori`, and — most important — the `Execute` method on interface
  `Bifrost LangModel Provider ori`. That last one is load-bearing: every provider's implementing
  `Execute` is deliberately left undocumented on the grounds that the interface carries the contract,
  which only holds once the interface method actually does. 134 added lines, all beginning with `///`,
  no executable AL touched.
- **HTML help** — not applicable, see check 8.
- **README.md** — rebuilt, see check 7b.
- **CHANGELOG.md** — heading date moved to 2026-09-07; `### Fixed (2026-09-07)` and
  `### Changed (2026-09-07)` sections added for the two logic fixes, the permission grants, the
  read-isolation and SetLoadFields narrowing, the XML docs, the new test codeunit and the README
  rebuild.
- **`.claude/CLAUDE.md`** — the used/free test id note updated for the new test codeunit 96015.
- **Translations** — `Bifrost Language Models.is-IS.xlf` is **293/293 translated**, matching the
  generated `.g.xlf` unit for unit, with no `needs-translation` state and no leftover "Bragi" text.
  The one new label added by this run (`Connection test failed. %1`) was merged into the Icelandic
  file by hand as `Tengipróf mistókst. %1`.

## Check 10 — Unit tests

| Container | Company | Codeunits | Tests | Passed | Failed |
| --- | --- | ---: | ---: | ---: | ---: |
| `bc28-is` (`f068155f0c39dev`) | CRONUS IS | 12 | 178 | **178** | 0 |
| `bc28-w1` (`f089d7daffb9dev`) | CRONUS International Ltd. | 12 | 178 | **178** | 0 |

App and test app were rebuilt and published to both containers with `SchemaUpdateMode=Synchronize`
before the runs. Both containers returned `422 … another service is currently modifying the state of
extensions` on the way and were retried.

Coverage added by this change:

- **`LLM Req Log Masker Tests` (codeunit 96015, 10 tests)** — the masker had no test coverage at all,
  which is a poor place for a gap: it decides what an administrator reading the request log gets to
  see of an LLM call. Covered: request and response body passed through verbatim in debug mode,
  redacted to `***REDACTED***` outside it, an empty response body staying empty, error text surviving
  both modes, and `GetBaseUrl` stripping path and query (OpenAI, the Gemini `generateContent` URL with
  a query string, a host with no path, a value that is not a URL, and the empty string).

One pre-existing test failure was found and fixed:

- ❌ → ✅ **`LangModel Setup Page Tests.SetupOri_ExposesTheSingleLangModelAppsAction`** failed with
  *"The following UI handlers were not executed: NotificationHandler"*. The test declares
  `[HandlerFunctions('NotificationHandler')]` but opens Foundation's `Setup ori`, and the HttpClient
  notification moved from the `Setup ori` page extension to `LangModel Setup ori` in commit `4015e41`
  — so no notification is sent and the declared handler can never run. The attribute was removed and
  a comment added saying why, so it does not get put back. The other two tests in the codeunit open
  `LangModel Setup ori`, do receive the notification, and keep their handler.

Codeunits without direct test coverage, all HTTP- or platform-bound: `LangModel Chat Proxy ori`,
`Copilot Chat Proxy ori`, `Anthropic LangModel Proxy ori`, `MCP Tool Executor ori`,
`Chat Providers Install ori`, `Chat Http Notif. Action ori`, `Copilot Install ori`,
`Copilot Upgrade ori`. Their behaviour is exercised indirectly through `Mock Bifrost Chat Provider`
and the 73 `MCP Tool Server Tests`.

## Check 11 — Story-Doc consistency — skipped

No `stories/` folder in this repository and no `// Story #N` traceability comments in the diff.

## Check 12 — Logic Review

**Scope note.** The diff against `main` is the entire extension: 123 files, 19 163 insertions. That
is far past the 10-file cap, so five files were deep-reviewed by changed-line count —
`MCP Tool Server ori` (1 169), `Anthropic LangModel Proxy ori` (655), `Gemini LangModel Prov. ori`
(541), `Bifrost LangModel Card ori` (483), `xAI LangModel Prov. ori` (403) — plus the three shared
provider files they depend on. The remaining files got mechanical checks 1–11 and 14 only.

Acceptance criteria were inferred from the code (no story exists), so treat them as the reviewer's
reading of intent, not as requirements. Of 34 inferred criteria, 26 verified clean.

### Fixed in this run (2)

- ⚠️ **F2 · Logic · fixed — a failed Google Gemini connection test showed the administrator nothing
  at all.** `Gemini LangModel Prov. ori.DoGetAvailableModels` never checked `IsSuccessStatusCode`, so
  a 401 or 403 body (valid JSON with no `models` key) fell through to `exit(false)` without calling
  `SetErrorMessage`. `DoTestConnection` passed that straight on, and `Bifrost LangModel Card ori` then
  called `Error('')` — an empty error, which aborts silently. Enter a wrong Gemini key, press **Test
  Connection**, and nothing happens. The procedure now reports the provider's own error detail on all
  five failure paths, reusing the file's existing `CallFailedErr` and `ApiStatusErr` labels so no new
  translation unit was needed. The xAI provider was already correct here; Gemini was the outlier.
- ⚠️ **F3 · Logic · fixed — a failed connection test left the session pinned to the tested model.**
  `Bifrost LangModel Card ori` raised `Error(TempArgument.GetErrorMessage())` on the line *before*
  `TestCtx.ClearLanguageModel()`, so the clear never ran. `Bifrost LangModel Test Ctx ori` is
  `SingleInstance` and `Bifrost Chat Mgt ori.GetLangModelProviderWithModel` gives it priority over the
  user's own assignment — so for the rest of that session every chat ran on the model whose test had
  just failed, and a personal API key saved from the chat would have been stored under that model's
  code. The context is now cleared before the outcome is reported. The model lookup on the same page
  already cleared on both paths, which is what makes this look accidental rather than deliberate.

### Open findings (3) — reported, not fixed

- ⚠️ **F1 · Logic · needs a design decision — the agentic tool loop has no iteration cap anywhere.**
  `ControlAddIn/scripts/BifrostChat.js:330-366` runs `ChatMessageResult` → `executeNextToolCall` →
  `ContinueWithToolResults` → AL calls the model again → `tool_calls` again, with no round counter.
  `LangModel Chat Proxy ori:60-91` and `Anthropic LangModel Proxy ori:184-219` are stateless per call,
  and `conversationState` carries only `messages`, `model` and `systemPrompt`. A model that keeps
  re-requesting a failing tool loops until the user closes the page, each round a paid API call that
  also executes BC tools — including `set_records` writes. Suggested fix: carry a `round` counter in
  `conversationState` and return a `reply` instead of `tool_calls` past ~10–15. **Where the cap lives
  is the decision**: `conversationState` comes back from the client, so a client-side counter is
  advisory only and the real ceiling has to be enforced in AL.
- ⚠️ **F4 · Robustness — Request Debug Mode logs only the calls that succeeded.**
  `LangModel API Client ori:89-101` buffers the failure detail and then raises `Error`, which unwinds
  past every caller's `LogLastRequest()` — Gemini:172, xAI:166 and :214, OpenAI:153, Azure:159,
  CustomLLM:151. `Anthropic LangModel Proxy ori:300-312` has the same shape, with `LogApiCall` sitting
  after both `Error` statements. Debug mode exists to diagnose failing calls, and those are exactly
  the ones missing from the log. `LangModel Chat Proxy ori:118-122` already shows the correct pattern
  (log on both branches). Mechanical, but it touches the error flow of six provider files, so it was
  left for a focused change rather than folded into a gateway run.
- ⚠️ **F5 · Robustness — malformed tool arguments are silently dropped and the tool runs with no
  arguments.** `LangModel Chat Proxy ori:315-318` uses
  `if (ArgumentsText <> '') and InputObject.ReadFrom(ArgumentsText)`; when the model emits an
  unparseable `arguments` string — a routine tool-calling failure — the `arguments` key is simply
  omitted. `Bifrost Chat FactBox ori:205` and `Chat Focus ori:178` then also ignore
  `Arguments.ReadFrom`'s return, so `get_records` runs with no `tableName` and the model gets a
  confusing downstream error instead of "your arguments were not valid JSON", which it could act on by
  retrying. Fix needs a new error label plus its Icelandic translation.

### Note not promoted to a finding

Gemini's and xAI's `CompletePrompt` let `SendToEndpoint`'s `Error` escape, while Anthropic returns
`{"error": …}` — so the error mapping in `LLM Prompt Compl Impl ori:119-127` only ever fires for
Anthropic. Left out because 5 of 6 providers share the behaviour, which reads as a deliberate
convention, and confirming it needs Foundation's task runner open to see whether it catches the error
and produces `status = Error`. **Worth one check by someone with Foundation open.**

---

## Security

Full `security-audit.yaml` re-run, all 8 phases. **No Critical and no High findings.**

### Clean, stated explicitly

- ✅ **No provider API key reaches the JavaScript control add-in.** `apiKey` in the config JSON is a
  non-secret marker: `Bifrost Chat Argument ori.GetApiKeyIndicator()` returns `'set'` or `''`, and all
  six external providers emit that, never the key (Anthropic:105, AzureOpenAI:107, CustomLLM:101,
  Gemini:104, OpenAI:103, xAI:101). Copilot omits the property entirely. `BifrostChat.js` contains
  **zero occurrences** of `fetch`, `XMLHttpRequest`, `Authorization` or any provider hostname; it uses
  `config.apiKey` only as a truthiness gate and routes every request back through
  `InvokeExtensibilityMethod('SubmitChatMessage', …)`.
- ✅ **No API key in any request URL.** Every provider sets the key in a header:
  `x-goog-api-key` (Gemini native and model list), `Authorization: Bearer` (OpenAI, xAI, Gemini chat),
  `x-api-key` (Anthropic, Custom LLM), `api-key` (Azure OpenAI). The classic Gemini `?key=` query
  string is **not** used — a repo-wide grep for `key=` in URL construction returns nothing. With debug
  mode off, no LLM request-log row is written at all; with it on, the administrator sees the endpoint
  URL, status and duration, and `***REDACTED***` for both bodies.
- ✅ **SecretText end to end.** Zero `Unwrap` calls anywhere. Zero direct `IsolatedStorage` use — all
  keys go through Foundation's `Secret Store ori` via `LangModel Secrets ori`. 57 `[NonDebuggable]`
  attributes on every procedure whose signature touches a key. Headers are composed with
  `SecretStrSubstNo`, so the Bearer prefix never materialises the key as `Text`.
- ✅ **No permission elevation in the MCP tool server.** Neither `MCP Tool Server ori` nor
  `MCP Tool Executor ori` declares a `Permissions` property — a repo-wide grep for `Permissions =`
  returns only the four permission set objects. Tools run in the caller's own session through the
  ordinary dispatcher; `ToolExecutor.Run()` is error isolation, not privilege change. **BC's own
  permission system is the guard: a prompt cannot read or write anything the signed-in user could not
  reach through the UI.**
- ✅ **JSON encoding and filter injection.** Every payload is built with `JsonObject.Add` /
  `JsonArray.Add`; the only string-literal JSON is the static tool input schemas, which contain no
  variable data. `SetFilter` is used exactly twice, both parameterised with `'<>%1'`.
- ✅ Data classification (zero `ToBeClassified`), no hardcoded secrets, zero `http://` occurrences,
  control add-in XSS (every `innerHTML` write goes through `escapeHtml()` or an escaping
  `renderMarkdown()`, no `eval`), event exposure (one publisher, Booleans only), and temp-table safety.

### Findings (6)

| # | Sev | Finding | Disposition |
| --- | --- | --- | --- |
| SEC-1 | Low | `LLM Req Log Masker ori.GetBaseUrl` masks only the `Service Base URL` column; Foundation's `Request Logger ori:67-68` stores the full URL verbatim in `Service URL` alongside it. Harmless today because no provider puts a secret in the URL — a latent trap the moment a provider or a customer-supplied `Base URL` (`Text[250]`, free text) carries a query-string credential. | **Decision** — sanitise at the `Logger.Log` call sites, or have Foundation store the masked URL. Foundation-side either way. |
| SEC-2 | **Medium** | `MCP Tool Server ori:369-372` resolves *any* message type through an unguarded `Evaluate` with no allow-list, and `Bifrost Chat FactBox ori:197-211` executes the result with no confirmation. Combined with SEC-3, text stored in BC could steer the model into a `set_records` call. Blast radius is bounded by the user's own permissions, but a clerk with the chat gate gets an unattended write channel. | **Decision** — an allow-list or a `Confirm` on outbound (Set/Post/Delete) message types, or a read-only chat mode as the default. |
| SEC-3 | **Medium** | `LangModel Chat Proxy ori:174-220` concatenates record captions, the client-supplied `contextSkill` and the `Skill` blob into one flat system prompt under plain header lines (`RECORD CONTEXT:`, `SKILL REFERENCE:`, `CONTEXT SKILL:`, `USER INSTRUCTIONS:`) with no boundary markers, and `MCP Tool Server ori:352-366` returns tool results to the model unvalidated. Escaping is not the issue — the JSON writer handles that — *trust boundary marking* is. Capped at Medium because `Skill` is admin-authored. | **Decision** — wrap each injected block in unique fenced delimiters and strip the delimiter token from the content. |
| SEC-4 | Low | `Bifrost Chat FactBox ori:205` and `Chat Focus ori:178` ignore the return of `Arguments.ReadFrom(ArgumentsJson)`. Same root cause as logic finding F5. | **Decision** — needs a new error label + Icelandic translation. |
| SEC-5 | Low | `LangModel Secrets ori.ClearSecrets:103` and `MoveSecrets:122` skip `CheckServiceKeyPermission()`, unlike `SetServiceKey:230`, `ClearServiceKey:261` and `SetServiceKeyFromDialog:197`. Both are public on a codeunit granted by `BIFROST LLM ori`, so a holder **without** `BIFROST ChatSvc ori` can destroy or relocate the shared key by deleting or renaming a language model — or by calling `ClearSecrets` directly. Integrity and availability only; the value is never disclosed. | **Decision** — requiring `BIFROST ChatSvc ori` to delete a language model is a real UX trade-off, so this is a product call, not a mechanical fix. |
| SEC-6 | Low | The chat gate is checked on *visibility* (`ShowBifrostChat`, ~30 page extensions) and on the API path (`LLM Prompt Compl Impl ori:72`), but not inside `Bifrost Chat Mgt ori.SendChatMessage` or `ContinueWithToolResults`. Defence-in-depth gap only — the underlying data access stays permission-checked. | **Decision** — add `HasChatPermission()` at the entry of the two send procedures if defence in depth is wanted. |

---

## Check 13 — What I couldn't check

- **Skipped**: check 5 (no published baseline — initial phase), check 11 (no `stories/`), check 15
  (this is not the standards repository), check 8's HTML generation (documentation lives in the site
  repository by approved deviation).
- **Limited**: check 12 deep-reviewed 5 of 123 changed files — the scope cap. The other 118 got
  mechanical checks only. Acceptance criteria there were inferred from code, not from a ticket or a
  story, so they are the reviewer's reading of intent and should be dismissed where they do not match.
- **Not verified — runtime**: everything except the unit tests is static review. No provider was
  called against a live endpoint, so the Gemini fix (F2) was verified by reading and compiling, not by
  entering a wrong key and pressing Test Connection. No MCP message-type round trip was run through
  the `origo-bc-bc28-is` server for `LLM.Prompt.Complete`.
- **Not verified — outside this repository**: Foundation's `Secret Store ori`, `Dispatcher ori` and
  `Request Logger ori` were read only far enough to confirm no elevation and to locate SEC-1;
  Foundation's own security posture is a separate audit. Whether AppSource requires the `keyVaultUrls`
  entry for the Copilot managed-resource flow cannot be answered from here.
- **Not verified — data state**: the tests run against CRONUS IS and CRONUS International with
  whatever language models those companies hold. Behaviour with a large `Bifrost Language Model` table
  or a long chat history was not exercised.

## Check 14 — Role coverage

Activation guard met: the app depends on Foundation and introduces new user-facing tables, pages and
codeunits. All 40 grantable objects were mapped against the four permission sets.

### Fixed in this run (2)

- ✅ `BIFROST LLM ori` now grants `codeunit "Chat Providers Install ori"`. It was the only object in
  the app granted by no set at all. It is `Access = Internal` and runs only from
  `Copilot Install ori.OnInstallAppPerCompany` in system context, so the functional impact is nil —
  but the two sibling install/upgrade codeunits *are* granted, which made the omission an unexplained
  inconsistency rather than a deliberate exemption.
- ✅ `BIFROST Chat ori` and `BIFROST ChatSvc ori` now pair their `tabledata` grants with the
  object-level `table "Chat Gate ori" = X` and `table "Chat Svc Gate ori" = X`. Both gates already
  worked — `WritePermission()` reads the `tabledata` permission, which was present — so this is
  cosmetic consistency with the two `BIFROST LLM` sets, which already pair every `tabledata` with a
  `table … = X`. Before this change no set granted `table "Chat Svc Gate ori" = X` at all.

### Decisions (3) — reported, not fixed

- ⚠️ **DECISION-1 · `BIFROST LLM Rd ori` grants a page that writes on open.** The read-only set grants
  `page "LangModel Setup ori"`, and that page's `OnOpenPage:152` calls `LangModelSecrets.RegisterAll()`
  — which reaches Foundation's `Secret Store ori.Register` and `AppSecret.Insert(true)`. The set's own
  doc comment defends this by saying App Secrets is "already covered by `BIFROST Read ori`", but
  `BIFROST Read ori` grants `tabledata "App Secret ori" = R`, not `RIMD`. Only `BIFROST Full ori`
  survives the insert. In practice `Register` is idempotent and install, upgrade, insert and rename
  already keep the registrations current, so the failure window is narrow — but a read-only page
  should not write. Three incompatible resolutions: (a) drop `RegisterAll()` from `OnOpenPage` and
  leave registration to install/upgrade/insert/rename plus the **API Keys** action — the recommended
  one, and a behaviour change; (b) drop the page from the read-only set, losing the overview for
  read-only users; (c) add `page "App Secrets ori"` and `tabledata "App Secret ori" = RIM` to the read
  set, which contradicts its stated intent.
- ⚠️ **DECISION-2 · `Bifrost Chat FactBox ori:108` jumps to Foundation's `User Setup Editor ori`,
  which only `BIFROST Full ori` grants.** The FactBox is granted by both `BIFROST LLM ori` and
  `BIFROST LLM Rd ori`, so both expose an action that 403s for anyone without `BIFROST Full ori`.
  For the full set the fix is `page "User Setup Editor ori" = X` plus `tabledata "User Setup ori" = RM`;
  for the read-only set the Editor is a write surface, so the choice is to hide the action
  conditionally or accept the 403. Note the cross-layer question underneath: a feature app re-granting
  Foundation-owned objects from its own assignable set is the anti-pattern that DECISION-3 resolves.
- ⚠️ **DECISION-3 · no `permissionsetextension` folds `BIFROST LLM ori` into Foundation's
  `BIFROST Full ori`.** The sibling **Bifrost Attachments** has exactly that
  (`StorageFull.PermissionSetExt.al`, `permissionsetextension 10035635 "Storage Full ori" extends
  "BIFROST Full ori"`, with the doc comment "keep the two lists in step"). Without it a Bifröst
  administrator holding `BIFROST Full ori` gets nothing from this app and must be assigned
  `BIFROST LLM ori` separately — the opposite of the sibling's behaviour. **Deliberately not applied
  in a gateway run**: it grants every Bifröst full-admin the ability to run LLM calls and manage
  language models, which is a policy choice rather than a mechanical fix. Ready to apply as a new file
  `app/src/Permission Set/LLMFull.PermissionSetExt.al` using id **10035423** (the first free id),
  mirroring `BIFROST LLM ori` minus `page "App Secrets ori"` and `codeunit "Secret Store ori"`, which
  `BIFROST Full ori` already grants. `BIFROST Chat ori` and `BIFROST ChatSvc ori` stay out — both
  document that they must be assigned by hand.

### Decisions carried from Layer 1

- ⚠️ **DECISION-5 · `Try` prefix without `[TryFunction]`.** `LangModel Secrets ori.TryGetApiKey` and
  `Bifrost LangModel Test Ctx ori.TryGetLanguageModel` are public Boolean accessors mirroring base-app
  `SecretStore.TryGet`. Adding `[TryFunction]` would change behaviour (errors swallowed, and
  `TryGetApiKey` returns Boolean *and* has a `var SecretText` out parameter); renaming becomes a
  breaking change under AS0018 once published. Recommendation: accept as-is, or rename before the
  first publish — the window closes when 28.0.0.0 ships.
- ⚠️ **DECISION-6 · `Bifrost LangModel List ori:68`** holds 6 statements in an action trigger, every
  one a delegation to `Copilot Install ori`. Reducing it means adding a public `InitDefaults()` wrapper
  to an internal codeunit — a new surface, not a one-line edit. Behaviour today is correct.

## Check 15 — Platform integration — skipped

This PR targets a customer/product app, not `bc-dev-standards`.

---

## Summary of changes made by this gateway run

| Area | File | Change |
| --- | --- | --- |
| Logic fix | `app/src/Providers/Gemini/GeminiLangModelProv.Codeunit.al` | `DoGetAvailableModels` reports the provider error on all five failure paths (F2) |
| Logic fix | `app/src/BifrostChat/LanguageModel/BifrostLangModelCard.Page.al` | Test Connection clears the session test context before reporting; new `TestFailedErr` label (F3) |
| Permissions | `app/src/Permission Set/BIFROSTLLM.PermissionSet.al` | grants `codeunit "Chat Providers Install ori"` |
| Permissions | `app/src/Permission Set/BIFROSTChat.PermissionSet.al` | adds `table "Chat Gate ori" = X` |
| Permissions | `app/src/Permission Set/BIFROSTChatSvc.PermissionSet.al` | adds `table "Chat Svc Gate ori" = X` |
| Performance | `BifrostChatMgt.Codeunit.al`, `LangModelProvBase.Codeunit.al`, `LangModelSecrets.Codeunit.al`, `LangModelSetup.Page.al`, `BifrostChatFactBox.Page.al`, `ChatFocus.Page.al`, `BifrostLanguageModel.Table.al` | `ReadIsolation = ReadUncommitted` on read-only probes; `SetLoadFields` narrowing |
| Documentation | `BifrostChatArgument.Table.al`, `MCPToolServer.Codeunit.al`, `BifrostChatUtils.Codeunit.al`, `BifrostLangModelProvider.Interface.al` | 25 XML doc blocks (134 lines, comment-only) |
| Tests | `test/test/Providers/LLMReqLogMaskerTests.Codeunit.al` | new codeunit 96015, 10 tests |
| Tests | `test/test/Setup/LangModelSetupPageTests.Codeunit.al` | stale `NotificationHandler` removed, with a comment saying why |
| Translations | `app/Translations/Bifrost Language Models.is-IS.xlf` | one new unit, 293/293 translated |
| Docs | `README.md` | rebuilt against the mandatory Origo template, all 90 objects listed |
| Docs | `CHANGELOG.md` | date moved to 2026-09-07, Fixed and Changed sections added |
| Docs | `.claude/CLAUDE.md` | test id note updated for 96015 |

---

⚠️ Two site-repository items and eight decisions are open — none of them blocking. The two site items
(`bragi-setup` on `main`, and the "Bragi" naming in `apps.ts` and the folder slugs) belong to
`businesscentralal/bifrost` and need to move with or before this PR. The `EULA` and `keyVaultUrls`
questions must be answered before AppSource submission. The rest — the tool-loop cap (F1), failure
logging (F4), tool-argument validation (F5/SEC-4), the MCP write allow-list (SEC-2), prompt trust
delimiters (SEC-3), the shared-key permission gap (SEC-5), the read-only setup page (DECISION-1),
`User Setup Editor` reachability (DECISION-2) and the `BIFROST Full ori` fold-in (DECISION-3) — are
product decisions, each with the exact change written out above.

*AI-assisted review. The acceptance criteria in check 12 were inferred from code, not from a ticket
or a story; dismiss any that do not reflect actual intent. Automated review cannot catch
domain-specific logic errors, and human review is still recommended for business rule correctness.*
