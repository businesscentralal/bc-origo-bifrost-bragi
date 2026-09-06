# Bifrost Bragi — Agent Context

This file gives AI agents the big-picture context needed to work in this repository correctly and safely.

---

## What This Extension Does

**Bifrost Bragi** is the chat module of the Bifröst platform for Microsoft Dynamics 365 Business Central. It puts a conversational assistant inside Business Central and gives that assistant a way to read and act on company data.

Four capabilities:

1. **Bifrost Chat** — a JavaScript control add-in rendered in a FactBox on 36 standard pages and on a focused full-page view. It carries the current record as conversation context.
2. **Language models** — a setup table that holds provider configuration (endpoint, model, token budget, API key handling) and a Markdown *skill* text that is injected into every conversation. One model can be the default; a model can also be assigned per user.
3. **Providers** — an interface + enum pair. Bragi ships the Microsoft Copilot / Azure OpenAI provider; other extensions add their own by extending the enum.
4. **MCP tool server** — exposes Business Central operations (search, read, write, files, memory, navigation, `invoke_message_type`) as Model Context Protocol tools, executed under the signed-in user's own permissions.

Plus one message type, `LLM.Prompt.Complete`, for one-shot completions in playbooks and scheduled tasks — no tools, no conversation state.

---

## Who Uses It

- Business Central users who chat with the assistant from a record page.
- Playbooks and scheduled tasks that need a reasoning or text-generation step, through `LLM.Prompt.Complete`.
- Origo and partner extensions that add a language model provider.

---

## Relationship to Bifrost Foundation

Bragi **depends on** Bifrost Foundation and installs beside it. Foundation owns the message loop, the setup, the user setup and the request log; Bragi extends them:

| Foundation object | Bragi extension | Why |
| --- | --- | --- |
| enum `Message Type ori` | `Bragi Message Type ori` | registers `LLM.Prompt.Complete` |
| enum `Request Log Type ori` | `Bragi Request Log Type ori` | registers `Copilot` + its secret masker |
| table `User Setup ori` | `User Setup Bragi ori` | field `Bifrost Language Model Code` |
| page `User Setup Editor ori` | `User Setup Editor Bragi ori` | the field + the chat FactBox |
| page `Setup ori` | `Setup Bragi ori` | the **Bifrost Language Models** action |

**Never** ask for a change in Foundation that Bragi can make through an extension object.

Foundation's `Help WhoAmI Get Impl ori` is `Access = Internal`. Bragi cannot call it. `Bifrost Chat Utils ori.GetIdentityJson()` runs the public `Help.WhoAmI.Get` message type through Foundation's `Msg Interface ori` instead, and strips the response `status` and the personal `systemPrompt`.

---

## Repository Structure

```
app/                          AppSource app "Bifrost Bragi" (Origo, range 10035335-10035484)
  src/
    BifrostChat/              Chat management, transfer, FactBox, focus page, model list
      ControlAddIn/           "Bifrost Chat ori" add-in + scripts/ + styles/
      Copilot/                Copilot provider, chat proxy, AOAI function, masker, install, upgrade
      Extensions/             36 page extensions that add the chat FactBox to standard pages
      LanguageModel/          Bifrost Language Model table, Card/List pages, provider enum + interface
      Message Types/          LLM.Prompt.Complete implementation + help codeunit
      Server/                 MCP tool server, tool executor, chat utils
    Extensions/               Extensions of Bifrost Foundation objects (enum, table, page)
    ChatGate.Table.al         "Chat Gate ori" — the permission gate table
    Permission Set/           BIFROST Bragi / BIFROST Bragi Rd / BIFROST Chat
  Translations/               Generated .g.xlf + the maintained is-IS.xlf
  assets/                     Logo250x250.png

test/                         Test app "Bifrost Bragi - Tests" (range 96000-96199)
  src/                        Mock provider + enum extensions, Bragi mock message type
  test/BifrostChat/           5 test codeunits, 114 tests
  reports/                    Internal test reports (not published)
```

Documentation is not kept in this repository. Product docs and in-product help for every Bifröst app
live in `businesscentralal/bifrost` and are published at https://bifrost.origo.is.

---

## Core Architectural Concepts

### Provider dispatch

`Bifrost Chat Mgt ori` resolves the active language model — the user's `Bifrost Language Model Code`, else the default model — reads its `Chat Provider` enum value and calls through the `Bifrost LangModel Provider ori` interface. The interface has a **single** method taking a `Bifrost Chat Argument ori` temporary record; the requested operation is a `Bifrost Chat Proc. Type ori` enum value on that record. New operations are added as enum values, so the interface signature never changes and existing providers keep compiling.

### The permission gate

`Chat Gate ori` is an empty table whose only purpose is `WritePermission()`. `Bifrost Chat Mgt ori.HasChatPermission()` reads it. Only `BIFROST Chat ori` grants write access — deliberately not `BIFROST Bragi ori`, so a chat licence is an explicit administrative act. The FactBox hides itself when the gate is closed or no language model resolves.

### Skill injection

The language model's Markdown skill text is prepended to the system prompt of every conversation. `Copilot Default Skill ori` supplies the shipped default.

---

## Rules for Agents

- **Do not modify `bc-origo-bifrost-core`.** Read it freely; the Foundation coordinator owns it.
- Namespace on line 1; `using Origo.Bifrost;` wherever a Foundation object is referenced.
- Object names are fixed. Renaming one is a breaking change for every tenant that has the app installed.
- New object ids come from 10035335-10035484 (tests 96000-96199), including enum extension value ids and table extension field ids.
- Compile with CodeCop + UICop + AppSourceCop and accept nothing but zero errors and zero warnings.
- Implementation means code **and** tests **and** documentation. Publish and run the tests on both containers before calling anything done.
- Never print, log or store the `BC28IS_USER` / `BC28IS_PASSWORD` values.
