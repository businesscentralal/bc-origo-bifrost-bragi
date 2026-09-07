# Changelog

All notable changes to Bifrost Language Models are documented here.

## [28.0.0.0] - 2026-09-07

### Added (2026-09-07) - setup wizard action

- `LangModel Setup ori` gains a **Setup Wizard** action (promoted, `Category_Process`) that opens
  Bifrost Foundation's `Setup Wizard ori` (page 10077925), which enables HTTP client requests for
  all Bifröst apps and walks through the credentials of every app.

### Changed (2026-09-07) - setup notifications and wizard

Setup notifications now live on the **Bifrost Setup** page only, for every app in the Bifröst family,
and their only action is **Start setup wizard**. Bifrost Language Models no longer raises a setup
notification of its own anywhere - it makes itself known to Bifröst Foundation instead, and Foundation
aggregates the outstanding setup work of all installed Bifröst apps in one place.

- **Added** codeunit 10035423 `LangModel Registration ori` (`Access = Internal`): one subscriber to
  Foundation's public `App Registry ori.OnRegisterApps` that calls `AddApp` with this app's module id,
  its display name and `Page::"LangModel Setup ori"`. Foundation fills in the HTTP status and the
  registered/missing credential counts itself. Granted by `BIFROST LLM ori`.
- **Removed** the HttpClient notification from `LangModel Setup ori`: the `ShowHttpClientNotification`
  procedure, its call in `OnOpenPage`, the `HttpClientDisabledMsg` and `EnableHttpClientLbl` labels and
  the now-unused `System.Apps` / `System.Environment.Configuration` usings. The page still shows the
  language models, the MCP tool count and the missing API keys.
- **Removed** codeunit 10035408 `Chat Http Notif. Action ori` entirely - the notification action it
  carried was its only purpose and nothing else referenced it. Its grant is gone from `BIFROST Chat ori`
  and object id 10035408 is free again.
- **Tests**: new `LangModel Registration Tests` (96016) asserts that `App Registry ori.GetApps` lists
  Bifrost Language Models under the module id returned by `LangModel Secrets ori.GetAppId()` and points
  at `LangModel Setup ori`. `LangModel Setup Page Tests` no longer declares `NotificationHandler` on the
  two page tests - the page sends no notification any more, so a declared handler could never run.

### Changed (2026-09-07) - tests run on Foundation's public API

- The test app no longer depends on Bifröst Foundation's internals: Bifrost Language Models - Tests has been removed
  from Foundation's `internalsVisibleTo`, and the test suite compiles and runs against a Foundation
  package that does not grant it. No test code had to change - the suite never touched a Foundation
  internal.


First release. The chat module was moved out of **Bifrost Foundation** 28.0.0.0 into this separate AppSource app, installed side by side with Foundation and depending on it.

### Fixed (2026-09-07)

- **A failed Google Gemini connection test no longer fails silently.** `Gemini LangModel Prov. ori.DoGetAvailableModels` returned `false` without setting an error message when the model list call failed, so **Test Connection** on the language model card raised an empty error and the administrator saw nothing at all. The procedure now checks `IsSuccessStatusCode` and reports the provider's own error detail for a transport failure, a non-success status (a wrong API key), an unparseable body, a missing `models` key and an empty model list.
- **A failed connection test no longer pins the session to the tested language model.** `Bifrost LangModel Card ori` raised the error before calling `Bifrost LangModel Test Ctx ori.ClearLanguageModel()`, so the single-instance test context survived and every later chat in that session ran on the model whose test had just failed. The context is now cleared before the outcome is reported, and the failure message is wrapped in a new **Connection test failed. %1** label. The model lookup on the same page already cleared on both paths.

### Changed (2026-09-07)

- `BIFROST LLM ori` grants `codeunit "Chat Providers Install ori"`, matching the existing grants for `Copilot Install ori` and `Copilot Upgrade ori`.
- `BIFROST Chat ori` and `BIFROST ChatSvc ori` pair their `tabledata` grants with the object-level `table "Chat Gate ori" = X` and `table "Chat Svc Gate ori" = X`, the way both `BIFROST LLM ori` sets already do.
- `ReadIsolation = ReadUncommitted` on the read-only record probes that had none: `Bifrost Chat Mgt ori.ShowBifrostChat` (the hot path — it runs on every one of the 36 chat page extensions), `LangModel Prov. Base ori.HasServiceGate`, `LangModel Secrets ori.RegisterAll`, `LangModel Setup ori.RefreshStatus`, and the company scans on `Bifrost Chat FactBox ori` and `Chat Focus ori`. `SetLoadFields` added to the language model reads in `Bifrost Chat Mgt ori.GetLangModelProvider` and the `Default` uniqueness check on `Bifrost Language Model ori`.
- XML documentation added to the 25 public procedures that had none: the 16 large-text accessors on `Bifrost Chat Argument ori`, the 5 public procedures on `MCP Tool Server ori`, 3 on `Bifrost Chat Utils ori`, and the `Execute` method on interface `Bifrost LangModel Provider ori` — the last one matters because every provider's implementing `Execute` is deliberately undocumented and inherits the interface contract.
- Tests: new `LLM Req Log Masker Tests` (10 tests) covering debug-mode passthrough, redaction outside debug mode, error text surviving both modes, and `GetBaseUrl` stripping path and query. `LangModel Setup Page Tests.SetupOri_ExposesTheSingleLangModelAppsAction` no longer declares a `NotificationHandler` — the HttpClient notification moved to `LangModel Setup ori`, so opening `Setup ori` sends none and the declared handler could never run. **178 tests, all passing on both bc28-is and bc28-w1.**
- `README.md` rebuilt against the mandatory Origo template (Overview, Functional Flow, Benefits, Logic Flow, Setup &amp; Configuration, Example Scenario, Objects, Dependencies, Documentation), with all 90 objects listed and the context-sensitive help slugs documented.

### Renamed before release

The app was called **Bifrost Bragi** while it was being built. Bifröst apps are named after what they do, not after a Norse figure, so everything below was renamed before the first release. Nothing here has shipped, so there is no upgrade path to keep: no object id changed, and no message type, secret code or JSON key changed.

- App `Bifrost Bragi` -> **`Bifrost Language Models`** (Icelandic "Bifröst mállíkön"); test app `Bifrost Bragi - Tests` -> `Bifrost Language Models - Tests`.
- Namespace `Origo.Bifrost.Bragi` -> **`Origo.Bifrost.LanguageModels`** (tests `Origo.Bifrost.LanguageModels.Test`).
- Repository `businesscentralal/bc-origo-bifrost-bragi` -> `businesscentralal/bc-origo-bifrost-language-models`.
- Objects: `Bragi Setup ori` -> `LangModel Setup ori`, `Bragi Secrets ori` -> `LangModel Secrets ori`, `Bragi Message Type ori` -> `LangModel Message Type ori`, `Bragi Request Log Type ori` -> `LangModel Req Log Type ori`, `Setup Bragi ori` -> `Setup LangModel ori`, `User Setup Bragi ori` -> `User Setup LangModel ori`, `User Setup Editor Bragi ori` -> `User Setup Editor LangMdl ori`. Test objects: `Bragi Mock Get Msg Co` -> `LangModel Mock Get Msg Co`, `Bragi Mock Message Type` -> `LangModel Mock Message Type` (value `Bragi.Mock.Get` -> `LangModel.Mock.Get`), `Bragi Secrets Tests` -> `LangModel Secrets Tests`, `Bragi Setup Page Tests` -> `LangModel Setup Page Tests`.
- Permission sets: `BIFROST Bragi ori` -> **`BIFROST LLM ori`**, `BIFROST Bragi Rd ori` -> **`BIFROST LLM Rd ori`**. `BIFROST LangModel ori` / `BIFROST LangMdl Rd ori` would have been 21 and 22 characters; AL caps a permission set object name at 20, so the set uses the `LLM` stem that the app already uses for `LLM.Prompt.Complete`, `LLM Prompt Compl Impl ori` and `LLM Req Log Masker ori`. `BIFROST Chat ori` and `BIFROST ChatSvc ori` are unchanged.
- Icelandic captions that carried the old app name now read "Bifröst mállíkön" / "Bifröst mállíkana".
- The documentation site slug stays `bragi` for now (`help`, `contextSensitiveHelpUrl` and `ContextSensitiveHelpPage = 'bragi-setup'`); the folders in `businesscentralal/bifrost` are renamed in a separate change, and the app.json URLs follow then.

### Added

- **App identity**: `Bifrost Language Models` (new app id), test app `Bifrost Language Models - Tests`. Object range 10035335-10035484, test range 96000-96199. Namespace `Origo.Bifrost.LanguageModels` (tests `Origo.Bifrost.LanguageModels.Test`). Depends on Bifrost Foundation 28.0.0.0. Help published to <https://businesscentralal.github.io/bifrost>.
- **Bifrost Chat**: control add-in `Bifrost Chat ori` with its scripts and styles, `Bifrost Chat FactBox ori`, `Chat Focus ori`, `Bifrost Chat Model List ori`, `Bifrost Chat Mgt ori`, `Bifrost Chat Transfer ori`, `Bifrost Chat Argument ori`, `Bifrost Chat Proc. Type ori`, `Bifrost Chat Utils ori` and 36 page extensions `Bifrost Chat <Page> ori` that put the FactBox on the customer, vendor, item, sales, purchase, ledger entry and incoming document pages.
- **Language models**: table `Bifrost Language Model ori` with `Bifrost LangModel Card ori` / `Bifrost LangModel List ori`, provider enum `Bifrost LangModel Prov. ori`, provider interface `Bifrost LangModel Provider ori`, default implementation `Bifrost LangModel None ori` and `Bifrost LangModel Test Ctx ori`.
- **Copilot provider**: `Copilot LangModel Prov. ori`, `Copilot Chat Proxy ori`, `Copilot AOAI Func Impl ori`, `Copilot Req Log Masker ori`, `Copilot Default Skill ori`, `Copilot Capability ori` (enum extension on Microsoft's `Copilot Capability`), plus the install codeunit `Copilot Install ori` (Subtype = Install) that registers the capability and `Copilot Upgrade ori`.
- **MCP tool server**: `MCP Tool Server ori` and `MCP Tool Executor ori`, giving the assistant read and write access to Business Central under the signed-in user's own permissions.
- **Chat providers moved from Origo Cloud Events Chat**: the six external providers previously shipped in the standalone *Origo Cloud Events Chat* AppSource app (which Bifrost Language Models replaces) are now registered on `Bifrost LangModel Prov. ori` (values `OpenAI`, `Azure OpenAI`, `Custom LLM`, `Anthropic`, `xAI`, `Google`):
  - `OpenAI LangModel Prov. ori` (Bearer token), `Azure OAI LangModel Prov. ori` (`api-key` header, deployment-specific Chat/Models Path), `Custom LLM LangModel Prov. ori` (`x-api-key`, OpenAI-compatible self-hosted endpoints), `Anthropic LangModel Prov. ori` + `Anthropic LangModel Proxy ori` (own Messages API), `xAI LangModel Prov. ori` (Responses API for files), `Gemini LangModel Prov. ori` (OpenAI-compatible chat, native `generateContent` for files).
  - Shared infrastructure: `LangModel Prov. Base ori` (config resolution, HttpClient gate, multi-modal message building), `LangModel API Client ori` (HTTP + response parsing), `LangModel Chat Proxy ori` (the OpenAI-compatible agentic tool loop against `MCP Tool Server ori`).
  - Shared (service) API key gate: table `Chat Svc Gate ori` and permission set `BIFROST ChatSvc ori`, separate from `BIFROST Chat ori` so an administrator can delegate "manage the shared key" without granting general chat execute permission.
  - Request logging: value `LLM` added to `LangModel Req Log Type ori` (masker `LLM Req Log Masker ori`, redacts request/response bodies outside debug mode).
  - `Chat Http Notif. Action ori` and a new `OnOpenPage` trigger on `Setup LangModel ori` warn the administrator when HttpClient requests are not allowed for the extension - every external provider needs them.
  - Data take-over: `Chat Providers Install ori.TakeOverChatProviderData()`, called from `Copilot Install ori.OnInstallAppPerCompany`, copies rows from the legacy app's `CE Chat Service Gate ori` table (table 10035495, a permission-gate table that never held any rows) into `Chat Svc Gate ori` when the legacy app is still installed and the new table is empty.
  - Not migrated: the legacy Setup Wizard page and its registration codeunit (superseded by the Bifrost Language Model Card/List and User Setup Editor, which configure providers per language model rather than through a single wizard), and the unused `CE Chat Tool Runner ori` codeunit (dead code - no provider called it).
- **Message type** `LLM.Prompt.Complete`: `LLM Prompt Compl Impl ori` and `LLM Prompt Compl Help ori`.
- **Permission sets**: `BIFROST LLM ori` (full), `BIFROST LLM Rd ori` (read-only), the moved `BIFROST Chat ori` gate over table `Chat Gate ori` (now also grants execute on every chat provider codeunit), and `BIFROST ChatSvc ori` over table `Chat Svc Gate ori`. Neither Bifrost Language Models set grants write access to either gate - both stay explicit, separately assignable permissions.
- **Extensions of Bifrost Foundation** (Foundation removed these couplings in 28.0.0.0):
  - `LangModel Message Type ori` - adds `LLM.Prompt.Complete` to enum `Message Type ori`.
  - `LangModel Req Log Type ori` - adds `Copilot` to enum `Request Log Type ori`, with `Copilot Req Log Masker ori` as the masker.
  - `User Setup LangModel ori` - adds field `Bifrost Language Model Code` to table `User Setup ori`.
  - `User Setup Editor LangMdl ori` - adds the language model field and the Bifrost Chat FactBox to page `User Setup Editor ori`.
  - `Setup LangModel ori` - adds the single **Bifrost Language Models Setup** action (and its promoted actionref) to the **Apps** group of page `Setup ori`.
- **Test app**: 5 test codeunits with 116 tests (`Bifrost Chat Mgt Tests`, `Bifrost Language Model Tests`, `Bifrost Chat Transfer Tests`, `Bifrost Chat Utils Tests`, `MCP Tool Server Tests`), the mock provider `Mock Bifrost Chat Provider` with its enum extension, and `LangModel Mock Get Msg Co` + `LangModel Mock Message Type` - a Bifrost Language Models-owned replacement for the Foundation test app's `Bifrost.Mock.Get` type, so the Bifrost Language Models tests do not depend on Foundation's test app. Plus 4 provider test codeunits (`LangModel Prov Base Tests`, `LangModel API Client Tests`, `LangModel Providers Tests`, `Chat Svc Gate Tests`) covering config resolution, token-usage parsing, multi-modal message building, response-text extraction and per-provider metadata dispatch, and 2 setup/secret test codeunits (`LangModel Secrets Tests`, `LangModel Setup Page Tests`) covering the secret code layout, registration with the right scope, the set/is-set/clear round trip of both keys, the personal-before-shared read order, clean-up on delete and rename, and that the Bifrost Language Models setup page opens and `Setup ori` carries the single Apps action. 168 tests in total across 11 test codeunits.
- **Bifrost Language Models setup page and the shared Bifröst secret store** (platform alignment with Bifrost Foundation 28.0.0.0):
  - `LangModel Setup ori` (page 10035421, `ContextSensitiveHelpPage = 'bragi-setup'`) - the app's own setup page, opened from the **Apps** group on `Setup ori`. It reports the number of language models and the default one, the number of MCP tool server tools, and how many language models still need an API key, with actions to the language model list and to **Bifrost App Secrets** filtered to Bifrost Language Models. The HttpClient notification moved here from the `Setup ori` page extension.
  - `LangModel Secrets ori` (codeunit 10035422, `Access = Public`) - this app's facade over Foundation's `Secret Store ori`. It owns the secret codes, registers them, resolves the API key of a request (personal key first, then the shared key, both with `MarkUsed`), and clears them when a language model is deleted or renamed.
  - Secret codes per language model: `LANGMODEL-<Code>-API-KEY` (scope **Company**, the shared key) and `LANGMODEL-<Code>-USER-API-KEY` (scope **Company And User**, the personal key). `<Code>` is the uppercased language model code; the longest possible code is 43 characters, so a `Code[20]` model code never has to be truncated to fit `Code[50]`.
  - Both codes are registered when a language model is inserted or renamed, and from `Copilot Install ori.OnInstallAppPerCompany` and the new `Copilot Upgrade ori.OnUpgradePerCompany` for every existing language model. Registration is idempotent.
- Icelandic translation `app/Translations/Bifrost Language Models.is-IS.xlf` (253 units, all translated), HTML help in `app/Help/en-US` and `app/Help/is-IS` (`BifrostChat.html`, `BifrostLangModelCard.html`, `BifrostLangModelList.html`, `index.html`).

### Changed

- Object ids were renumbered from the Foundation range into 10035335-10035484 and test ids into 96000-96199. Object **names are unchanged**, so no caller or configuration that refers to an object by name is affected.
- `Bifrost Chat Utils ori.GetIdentityJson()` replaces the direct call into Foundation's internal `Help WhoAmI Get Impl ori`: the chat pages now build the connection-validation identity by running the public `Help.WhoAmI.Get` message type through Foundation's `Msg Interface ori`, dropping the response envelope status and the personal system prompt.
- `Chat Gate ori` moved out of Foundation's posting-gate folder and is now a Bifrost Language Models table.
- Help and documentation moved to <https://businesscentralal.github.io/bifrost> (source repository `businesscentralal/bifrost`), where the English and Icelandic content for every Bifröst app is published together. The `app/docs` and `app/Help` folders were removed from this repository; `help` in `app.json` now points at `https://businesscentralal.github.io/bifrost/en-us/bragi/` and `contextSensitiveHelpUrl` at `https://businesscentralal.github.io/bifrost/{0}/help/bragi/`.
- Context-sensitive help pages are now addressed by slug instead of by HTML file name: `ContextSensitiveHelpPage` is `bifrost-chat` (36 page extensions), `bifrost-lang-model-card` and `bifrost-lang-model-list`.
- **API keys moved out of this app's own IsolatedStorage into the Bifröst secret store.** The six inline storage sites that used the keys `Bifrost_Chat_Usr_<SystemId>_<UserSecurityId>` and `Bifrost_Chat_Svc_<SystemId>` (all `DataScope::Company`) now go through `LangModel Secrets ori`:
  - `Bifrost LangModel Card ori` - the two masked **Personal API Key** / **Service API Key** fields are gone. The Authentication group now shows read-only **Personal Key Stored** / **Shared Key Stored** flags plus a hint when neither key is set, and four actions - **Set / Clear Personal API Key** and **Set / Clear Shared API Key** - use Foundation's shared masked dialog (`Secret Store ori.SetFromDialog`). The shared-key actions stay gated by `BIFROST ChatSvc ori`.
  - `Bifrost Chat Mgt ori` - `SaveApiKey`, `SaveServiceApiKey`, `ClearCredentials`, `BuildArgument` and the `hasServiceKey` property in `BuildConfigJson`.
  - `Bifrost Language Model ori.OnDelete` - clears both secrets; new `OnInsert` and `OnRename` triggers register them (a rename carries over the values this user can read; personal keys of other users are re-entered).
  - `LLM Prompt Compl Impl ori.BuildChatArgument`.
  - The Bifrost Chat FactBox and Chat Focus `SaveApiKey` / `SaveServiceApiKey` triggers, through `Bifrost Chat Mgt ori`.
- **API keys are `SecretText` end to end.** `Bifrost Chat Argument ori.SetApiKey` takes and `GetApiKey` returns `SecretText`; `HasApiKey()` replaces the old `GetApiKey() = ''` checks. `LangModel API Client ori`, `LangModel Chat Proxy ori` and `Anthropic LangModel Proxy ori` pass the key as `SecretText` into the HTTP header (`SecretStrSubstNo` for the `Bearer` scheme). The key is never converted to `Text`: `SecretText.Unwrap()` is `OnPrem`-scoped and cannot be used in a Cloud app.
- **`apiKey` in the chat control add-in configuration is no longer the key.** The JavaScript only tests the property for truthiness - it routes every request back through AL - so `ConfigJson.Add('apiKey', ...)` now receives the non-secret marker from `Bifrost Chat Argument ori.GetApiKeyIndicator()`. The API key itself no longer leaves the server.
- **Google Gemini authenticates with the `x-goog-api-key` header** instead of the `?key=` query string, on both the native `generateContent` call and the model list. The key no longer appears in a request URL, which also removes the URL masking the request log needed.
- `Setup LangModel ori` (page extension 10035403) was reduced to what Foundation's platform rules allow a dependent app to add: one action in `addlast(Apps)` opening `LangModel Setup ori`, plus its actionref in `addlast(Category_Apps)`. The **Bifrost Language Models** action, its promoted actionref and the `OnOpenPage` HttpClient notification moved to `LangModel Setup ori`.
- `BIFROST LLM ori`, `BIFROST LLM Rd ori` and `BIFROST Chat ori` grant the new `LangModel Setup ori` page and `LangModel Secrets ori` codeunit, plus Foundation's `Secret Store ori` codeunit and `App Secrets ori` page.

### Migration

- **API keys do not migrate.** Values written by an earlier build (or by the legacy *Origo Cloud Events Chat* app) live in that extension's own IsolatedStorage and are unreachable from the Bifröst secret store. After deployment every language model shows **no key stored**; an administrator re-enters the shared key once per language model, and each user re-enters their personal key once. The Bifrost Language Models setup page and the language model card both show this hint while a key is missing, and **Bifrost App Secrets** lists every registered key with its state.
- Renaming a language model changes its secret codes. The values this user can read are carried over automatically; personal keys belonging to other users must be entered again. The registry rows of the old codes stay behind in **Bifrost App Secrets** with no value - Foundation's `Secret Store ori` has no unregister operation.
