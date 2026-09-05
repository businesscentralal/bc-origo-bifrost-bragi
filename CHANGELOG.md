# Changelog

All notable changes to Bifrost Bragi are documented here.

## [28.0.0.0] - 2026-09-05

First release. The chat module was moved out of **Bifrost Foundation** 28.0.0.0 into this separate AppSource app, installed side by side with Foundation and depending on it.

### Added

- **App identity**: `Bifrost Bragi` (new app id), test app `Bifrost Bragi - Tests`. Object range 10035335-10035484, test range 96000-96199. Namespace `Origo.Bifrost.Bragi` (tests `Origo.Bifrost.Bragi.Test`). Depends on Bifrost Foundation 28.0.0.0. Help published to `origopublic/help/BifrostBragi/bc28/`.
- **Bifrost Chat**: control add-in `Bifrost Chat ori` with its scripts and styles, `Bifrost Chat FactBox ori`, `Chat Focus ori`, `Bifrost Chat Model List ori`, `Bifrost Chat Mgt ori`, `Bifrost Chat Transfer ori`, `Bifrost Chat Argument ori`, `Bifrost Chat Proc. Type ori`, `Bifrost Chat Utils ori` and 36 page extensions `Bifrost Chat <Page> ori` that put the FactBox on the customer, vendor, item, sales, purchase, ledger entry and incoming document pages.
- **Language models**: table `Bifrost Language Model ori` with `Bifrost LangModel Card ori` / `Bifrost LangModel List ori`, provider enum `Bifrost LangModel Prov. ori`, provider interface `Bifrost LangModel Provider ori`, default implementation `Bifrost LangModel None ori` and `Bifrost LangModel Test Ctx ori`.
- **Copilot provider**: `Copilot LangModel Prov. ori`, `Copilot Chat Proxy ori`, `Copilot AOAI Func Impl ori`, `Copilot Req Log Masker ori`, `Copilot Default Skill ori`, `Copilot Capability ori` (enum extension on Microsoft's `Copilot Capability`), plus the install codeunit `Copilot Install ori` (Subtype = Install) that registers the capability and `Copilot Upgrade ori`.
- **MCP tool server**: `MCP Tool Server ori` and `MCP Tool Executor ori`, giving the assistant read and write access to Business Central under the signed-in user's own permissions.
- **Message type** `LLM.Prompt.Complete`: `LLM Prompt Compl Impl ori` and `LLM Prompt Compl Help ori`.
- **Permission sets**: `BIFROST Bragi ori` (full), `BIFROST Bragi Rd ori` (read-only) and the moved `BIFROST Chat ori` gate over table `Chat Gate ori`. Neither Bragi set grants write access to the Chat Gate - `BIFROST Chat ori` stays the explicit gate that lets a user chat.
- **Extensions of Bifrost Foundation** (Foundation removed these couplings in 28.0.0.0):
  - `Bragi Message Type ori` - adds `LLM.Prompt.Complete` to enum `Message Type ori`.
  - `Bragi Request Log Type ori` - adds `Copilot` to enum `Request Log Type ori`, with `Copilot Req Log Masker ori` as the masker.
  - `User Setup Bragi ori` - adds field `Bifrost Language Model Code` to table `User Setup ori`.
  - `User Setup Editor Bragi ori` - adds the language model field and the Bifrost Chat FactBox to page `User Setup Editor ori`.
  - `Setup Bragi ori` - adds the **Bifrost Language Models** action (and its promoted actionref) to page `Setup ori`.
- **Test app**: 5 test codeunits with 114 tests (`Bifrost Chat Mgt Tests`, `Bifrost Language Model Tests`, `Bifrost Chat Transfer Tests`, `Bifrost Chat Utils Tests`, `MCP Tool Server Tests`), the mock provider `Mock Bifrost Chat Provider` with its enum extension, and `Bragi Mock Get Msg Co` + `Bragi Mock Message Type` - a Bragi-owned replacement for the Foundation test app's `Bifrost.Mock.Get` type, so the Bragi tests do not depend on Foundation's test app.
- Icelandic translation `app/Translations/Bifrost Bragi.is-IS.xlf` (199 units, all translated), HTML help in `app/Help/en-US` and `app/Help/is-IS` (`BifrostChat.html`, `BifrostLangModelCard.html`, `BifrostLangModelList.html`, `index.html`).

### Changed

- Object ids were renumbered from the Foundation range into 10035335-10035484 and test ids into 96000-96199. Object **names are unchanged**, so no caller or configuration that refers to an object by name is affected.
- `Bifrost Chat Utils ori.GetIdentityJson()` replaces the direct call into Foundation's internal `Help WhoAmI Get Impl ori`: the chat pages now build the connection-validation identity by running the public `Help.WhoAmI.Get` message type through Foundation's `Msg Interface ori`, dropping the response envelope status and the personal system prompt.
- `Chat Gate ori` moved out of Foundation's posting-gate folder and is now a Bragi table.
