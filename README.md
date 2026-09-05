# Bifrost Bragi

**Publisher:** Origo
**Version:** 28.0.0.0
**Object ID range:** 10035335-10035484
**Namespace:** `Origo.Bifrost.Bragi`
**Depends on:** Bifrost Foundation 28.0.0.0

Bifrost Bragi is the chat module of the Bifröst platform. It adds a conversational assistant to Business Central: the **Bifrost Chat** control add-in and FactBox on 36 standard pages, a focused chat page, **language models** that hold the provider configuration and the skill text injected into every conversation, a **Copilot provider** built on Microsoft's Azure OpenAI service, an **MCP tool server** that lets the assistant read and act on Business Central data under the signed-in user's own permissions, and the `LLM.Prompt.Complete` message type for one-shot completions in playbooks and scheduled tasks.

Bragi was extracted from *Bifrost Foundation* in version 28.0.0.0. Foundation no longer contains chat; Bragi installs beside it and extends it. See [CHANGELOG.md](CHANGELOG.md).

## What Bragi adds to Bifrost Foundation

| Foundation object | What Bragi extends it with |
| --- | --- |
| enum `Message Type ori` | value `LLM.Prompt.Complete` (`Bragi Message Type ori`) |
| enum `Request Log Type ori` | value `Copilot` and its request log masker (`Bragi Request Log Type ori`) |
| table `User Setup ori` | field `Bifrost Language Model Code` (`User Setup Bragi ori`) |
| page `User Setup Editor ori` | the language model field and the Bifrost Chat FactBox (`User Setup Editor Bragi ori`) |
| page `Setup ori` | the **Bifrost Language Models** action (`Setup Bragi ori`) |

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
| `app/src/Permission Set/` | `BIFROST Bragi ori`, `BIFROST Bragi Rd ori`, `BIFROST Chat ori` |
| `app/docs/` | Markdown reference documentation (en-us, is-is) - source of truth for message contracts |
| `app/Help/` | HTML help (en-US, is-IS) published to origopublic blob storage |
| `test/` | Test app (`Bifrost Bragi - Tests`, object range 96000-96199) |
| `.AL-Go/`, `.github/` | AL-Go for GitHub / COSMO Alpaca pipeline configuration |

## Permission sets

| Set | Grants |
| --- | --- |
| `BIFROST Bragi ori` | Full access to language models and every Bragi object |
| `BIFROST Bragi Rd ori` | Read-only access to language models |
| `BIFROST Chat ori` | Write access to the Chat Gate - the gate that lets a user actually open a chat. Assign it on top of one of the sets above; it is deliberately not bundled into any other set. |

## Setup

1. Assign `BIFROST Bragi ori` (or `BIFROST Bragi Rd ori`) plus `BIFROST Chat ori` to the users who may chat.
2. Open **Bifrost Setup** and choose **Bifrost Language Models**. Create a language model, pick a provider, fill in the model settings and write the skill text.
3. Mark one language model as default, or assign a specific one per user on **User Setup Editor** in the **Language Model Code** field.
4. The Bifrost Chat FactBox appears on the supported pages once a user has both the permission and a resolvable language model.

## Development

- Open `al.code-workspace` in VS Code.
- Development containers: COSMO Alpaca `bc28-is` and `bc28-w1` (see `app/.vscode/launch.json`).
- Standards: [Origo BC Development Standards](https://github.com/OrigoSoftwareSolutions/bc-dev-standards). Project rules are in `.claude/CLAUDE.md`.
- Every object carries the mandatory `ori` suffix; the brand name is carried by the namespace, not by object names.

## Documentation

- English: `app/docs/en-us/` - Icelandic: `app/docs/is-is/`
- Message type reference: `app/docs/en-us/Chat_Message_Types.md`
- Provider extensibility: `app/docs/en-us/Bragi_Extensibility.md`

<!-- AUTO-UPDATE-START -->
# COSMO Alpaca AL-Go AppSource App Template

[![Use this template](https://github.com/microsoft/AL-Go/assets/10775043/ca1ecc85-2fd3-4ab5-a866-bd2e7e80259d)](https://github.com/new?template_name=Alpaca-AppSource-Template&template_owner=cosmoconsult)

This template repository can be used for managing AppSource Apps for Business Central.

It is a customized version of the [AL-Go-AppSource](https://github.com/microsoft/AL-Go-AppSource) template and is designed to be used with [COSMO Alpaca](https://cosmoconsult.com/cosmo-alpaca).

> [!NOTE]
> If you created this repository using the GitHub web UI (for example by clicking **Use this template** on GitHub.com) instead of creating it from the COSMO Alpaca VS Code extension, you must initialize it using the [COSMO Alpaca VS Code extension](https://marketplace.visualstudio.com/items?itemName=cosmoconsult.cosmo-alpaca).  To do this, simply right-click on the repository in VS Code and select _Initialize_.

Please go to https://aka.ms/AL-Go and [COSMO Docs](https://docs.cosmoconsult.com/en-us/cloud-service/alpaca) to learn more.
<!-- AUTO-UPDATE-END -->
