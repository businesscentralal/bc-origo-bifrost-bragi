# Bifrost Bragi

**Publisher:** Origo &nbsp;|&nbsp; **Version:** 28.0.0.0 &nbsp;|&nbsp; **Object ID range:** 10035335-10035484 &nbsp;|&nbsp; **Namespace:** `Origo.Bifrost.Bragi` &nbsp;|&nbsp; **Depends on:** Bifrost Foundation 28.0.0.0

Bifrost Bragi is the chat module of the Bifröst platform. It adds a conversational assistant to Business Central: the Bifrost Chat control add-in and FactBox, language models that hold the provider configuration and the skill text, seven chat providers (Copilot, OpenAI, Azure OpenAI, Custom LLM, Anthropic, xAI and Google/Gemini), an MCP tool server that lets the assistant read and act on Business Central data under the signed-in user's own permissions, and the `LLM.Prompt.Complete` message type.

Bragi was extracted from *Bifrost Foundation* in version 28.0.0.0 and replaces the standalone *Origo Cloud Events Chat* app. It installs beside Foundation and extends it - see [CHANGELOG.md](CHANGELOG.md).

## Documentation

All Bifröst documentation lives at [bifrost.origo.is](https://businesscentralal.github.io/bifrost) (repository `businesscentralal/bifrost`), in English and Icelandic. There are no `docs/` or `Help/` folders in this repository.

- [Product documentation](https://businesscentralal.github.io/bifrost/en-us/bragi/) - message types, setup, MCP tool server
- [In-product help](https://businesscentralal.github.io/bifrost/en-us/help/bragi/) - the pages Business Central opens from the help icon
- [Adding a chat provider](https://businesscentralal.github.io/bifrost/en-us/bragi/extensibility/)
- [Building on Bifröst](https://businesscentralal.github.io/bifrost/en-us/extensibility/)

## Repository layout

| Folder | Content |
| --- | --- |
| `app/` | The AppSource app (`Bifrost Bragi`) |
| `app/src/BifrostChat/` | Chat management, control add-in, FactBox, focus page, page extensions |
| `app/src/BifrostChat/LanguageModel/` | `Bifrost Language Model ori` table, Card/List pages, provider enum and interface |
| `app/src/BifrostChat/Copilot/` | Copilot provider, chat proxy, AOAI function, request log masker, install and upgrade |
| `app/src/BifrostChat/Server/` | MCP tool server and tool executor |
| `app/src/BifrostChat/Message Types/` | `LLM.Prompt.Complete` implementation and help codeunit |
| `app/src/Extensions/` | Extensions of Bifrost Foundation objects (enum, table, page) |
| `app/src/Providers/Shared/` | `LangModel Prov. Base ori`, `LangModel API Client ori`, `LangModel Chat Proxy ori`, `Chat Svc Gate ori`, `Chat Http Notif. Action ori`, `LLM Req Log Masker ori`, take-over codeunit |
| `app/src/Providers/OpenAI/`, `AzureOpenAI/`, `CustomLLM/`, `Anthropic/`, `xAI/`, `Gemini/` | The six external chat provider codeunits, one folder per provider |
| `app/src/Permission Set/` | `BIFROST Bragi ori`, `BIFROST Bragi Rd ori`, `BIFROST Chat ori`, `BIFROST ChatSvc ori` |
| `app/Translations/` | Icelandic translation (`Bifrost Bragi.is-IS.xlf`) |
| `test/` | Test app (`Bifrost Bragi - Tests`, object range 96000-96199) |
| `test/reports/` | Internal test reports - not published |
| `.AL-Go/`, `.github/` | AL-Go for GitHub / COSMO Alpaca pipeline configuration |

## Development

- Open `al.code-workspace` in VS Code.
- Development containers: COSMO Alpaca `bc28-is` and `bc28-w1` (see `app/.vscode/launch.json`).
- Build locally with `alc.exe` from the AL extension, with CodeCop, UICop and AppSourceCop enabled; symbols live in `app/.alpackages`. Zero errors and zero warnings beyond the suppressions in `app.json` is the bar.
- Publish and run the tests with `bc-origo-bifrost-core/tools/Publish-BifrostApp.ps1` and `Run-BifrostTests.ps1`.
- Standards: [Origo BC Development Standards](https://github.com/OrigoSoftwareSolutions/bc-dev-standards). Project rules are in `.claude/CLAUDE.md`.
- Every object carries the mandatory `ori` suffix; the brand name is carried by the namespace, not by object names.

<!-- AUTO-UPDATE-START -->
# COSMO Alpaca AL-Go AppSource App Template

[![Use this template](https://github.com/microsoft/AL-Go/assets/10775043/ca1ecc85-2fd3-4ab5-a866-bd2e7e80259d)](https://github.com/new?template_name=Alpaca-AppSource-Template&template_owner=cosmoconsult)

This template repository can be used for managing AppSource Apps for Business Central.

It is a customized version of the [AL-Go-AppSource](https://github.com/microsoft/AL-Go-AppSource) template and is designed to be used with [COSMO Alpaca](https://cosmoconsult.com/cosmo-alpaca).

> [!NOTE]
> If you created this repository using the GitHub web UI (for example by clicking **Use this template** on GitHub.com) instead of creating it from the COSMO Alpaca VS Code extension, you must initialize it using the [COSMO Alpaca VS Code extension](https://marketplace.visualstudio.com/items?itemName=cosmoconsult.cosmo-alpaca).  To do this, simply right-click on the repository in VS Code and select _Initialize_.

Please go to https://aka.ms/AL-Go and [COSMO Docs](https://docs.cosmoconsult.com/en-us/cloud-service/alpaca) to learn more.
<!-- AUTO-UPDATE-END -->
