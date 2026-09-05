# Chat Message Types

This document describes the chat-related message types in the Bifrost Bragi extension.

## Overview

Bifrost Bragi contributes one message type to the Bifrost Foundation dispatcher: `LLM.Prompt.Complete`. It is a one-shot completion against the language model configured on a **Bifrost Language Model** record — a system prompt plus a user prompt go in, a text response comes back.

The message type is deliberately minimal compared with the interactive Bifrost Chat FactBox:

- **No tools.** The MCP tool server is not attached, so the model cannot read or write Business Central data during the call.
- **No bootstrap.** No identity block and no language-model skill are injected. The caller's `system` value is the entire system prompt.
- **No conversation state.** Every call is independent; nothing is carried to a following call.

That makes it the general-purpose compute step for playbooks and scheduled tasks — date arithmetic, classification, extraction, translation, summarisation, filter generation and free-text generation — wherever no standard message type covers the step.

Bragi registers the type on Foundation's `Message Type ori` enum through `enumextension "Bragi Message Type ori"` (10035399), so it is dispatched exactly like a Foundation message type: through the `tasks` API endpoint, through the queue, or through the `call_message_type` MCP tool.

## Message Type List

| Message Type | Direction | Purpose |
|--------------|-----------|---------|
| [LLM.Prompt.Complete](#llmpromptcomplete) | Outbound | One-shot language model completion — send a prompt, get text back |

---

## LLM.Prompt.Complete

**Direction**: Outbound (Response to request)

**Purpose**: Sends a system prompt and a user prompt to the language model provider configured on the resolved Bifrost Language Model and returns the model's text response. Optionally passes a file — supplied inline or resolved from a Business Central attachment record — to providers that accept documents and images.

### Request Format

Bifrost parameters:
```json
{
  "specversion": "1.0",
  "type": "LLM.Prompt.Complete",
  "source": "MyApp v1.0",
  "datacontenttype": "application/json",
  "data": "{}"
}
```

#### Request Data Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `prompt` | String | Yes | The user prompt — the task or question for the model. |
| `system` | String | No | System prompt that guides the model's behaviour. Sent as-is; no bootstrap, identity block or skill is added. |
| `roleCode` | String (Code[20]) | No | Code of the Bifrost Language Model to use. Omit to use the caller's configured or default language model. |
| `file` | Object | No | Inline file passed straight through to the provider as the single entry of the payload `files` array. Use `data` (base64), `mimeType` and `fileName`. |
| `attachment` | Object | No | Reference to a Business Central attachment record that Bragi reads and converts into a file entry. Ignored when `file` is supplied. |

The `attachment` object:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `table` | String | Yes | `"Incoming Document Attachment"` or `"Document Attachment"`. Any other value is ignored and no file is sent. |
| `systemId` | GUID | Yes | System Id of the attachment record. A record that cannot be found or has no content is ignored and no file is sent. |

The resolved file entry carries `data` (base64 content), `fileName` (the record's name, with the file extension appended when it is missing) and `mimeType`, derived from the file extension:

| Extension | `mimeType` |
|-----------|------------|
| `pdf` | `application/pdf` |
| `png` | `image/png` |
| `jpg`, `jpeg` | `image/jpeg` |
| `gif` | `image/gif` |
| `webp` | `image/webp` |
| `xml` | `application/xml` |
| `json` | `application/json` |
| `txt`, `csv` | `text/plain` |
| anything else | `application/octet-stream` |

#### Example — Data Extraction

```json
{
  "prompt": "Extract the invoice number, date, and total from the following text:\n\nInvoice #4521\nDate: 2025-03-15\nTotal: 1250.00",
  "system": "Extract structured data from text. Return valid JSON with keys: invoiceNo, date, total.",
  "roleCode": "CLAUDE"
}
```

#### Example — Date Computation

```json
{
  "system": "Return ONLY a JSON object with startDate and endDate in YYYY-MM-DD format. No explanation.",
  "prompt": "Today is 2026-08-30. What are the first and last day of last month?"
}
```

Response text: `{"startDate":"2026-07-01","endDate":"2026-07-31"}`

#### Example — Classification

```json
{
  "system": "Classify the document. Return ONLY one of: Invoice, CreditMemo, DeliveryNote, PurchaseOrder, Unknown.",
  "prompt": "Vendor 30000, document dated 2026-08-14, lines reference return of 4 units."
}
```

#### Example — Filter Generation

```json
{
  "system": "Return ONLY a BC tableView filter string. No explanation.",
  "prompt": "Today is 2026-08-30. Filter Sales Invoice Header where Posting Date is in the previous fiscal quarter (April-June 2026) and Sell-to Customer No. starts with 1."
}
```

Response text: `WHERE(Posting Date=FILTER(2026-04-01..2026-06-30),Sell-to Customer No.=FILTER(1*))`

#### Example — Text Generation in Icelandic

```json
{
  "roleCode": "KAPPI",
  "system": "Write a polite payment reminder in Icelandic. Include amount and due date. Max 500 characters. Return ONLY the text.",
  "prompt": "Customer Alfreð Bjarnason, overdue amount 245.000 ISK, oldest due date 2026-07-15."
}
```

#### Example — Attachment from an Incoming Document

```json
{
  "system": "Extract invoice fields from the attached document. Return JSON: {vendorName, invoiceNo, date, totalAmount, currency}.",
  "prompt": "Extract the invoice fields.",
  "attachment": {
    "table": "Incoming Document Attachment",
    "systemId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
  }
}
```

#### Example — Inline File

```json
{
  "system": "Summarise the attached document in three sentences.",
  "prompt": "Summarise it.",
  "file": {
    "data": "JVBERi0xLjQKJcfsj6IK...",
    "mimeType": "application/pdf",
    "fileName": "Contract.pdf"
  }
}
```

### Response Format

**Content type**: `text/json`

| Field | Type | Description |
|-------|------|-------------|
| `status` | String | `"Success"` or `"Error"` |
| `text` | String | The completion text. Always present on success. |
| `reply` | String | The provider's raw reply field. Present when the provider returns `reply`; `text` is then copied from it. |
| `error` | String | Error message. Only present when `status` is `"Error"`. |
| `hint` | String | Pointer to `Help.Implementation.Get` for this message type. Only present when `status` is `"Error"`. |

Properties the provider adds beyond `text` and `reply` are passed through unchanged, so a provider that returns usage counters or a model name keeps them in the response.

#### Example Response

```json
{
  "reply": "{\"invoiceNo\":\"4521\",\"date\":\"2025-03-15\",\"total\":1250.00}",
  "status": "Success",
  "text": "{\"invoiceNo\":\"4521\",\"date\":\"2025-03-15\",\"total\":1250.00}"
}
```

#### Example Error Response

```json
{
  "status": "Error",
  "error": "No chat provider configured. Set up a Bifrost Language Model with a Chat Provider.",
  "hint": "For usage details, call the \"Help.Implementation.Get\" message type with subject \"LLM.Prompt.Complete\"."
}
```

### Provider Resolution

The language model — and with it the provider, base URL, model name, timeout, token limit and API key — is resolved in this order:

1. The **Try It** override from the Bifrost Language Model card, when a test is running in the current session.
2. The `roleCode` value from the request, when supplied. An unknown code is an error; it does not fall through.
3. The **Bifrost Language Model Code** on the caller's Bifrost User Setup record.
4. The Bifrost Language Model marked **Default**.
5. Nothing found — the `None` provider is used, which reports "not configured" and the call fails with `status: Error`.

The resolved provider is asked `IsConfigured` before the prompt is sent. A provider that answers `false` — Copilot that is not enabled in **Copilot & AI Capabilities**, or the `None` provider — stops the call before any payload leaves Business Central.

The API key is read from Isolated Storage in company scope: the caller's personal key first (`Bifrost_Chat_Usr_<language model SystemId>_<user security id>`), then the shared service key (`Bifrost_Chat_Svc_<language model SystemId>`). The Copilot provider needs no key — it uses Microsoft-managed resources.

### Table Reference

**Table**: Bifrost Language Model ori (10035335)

| No. | Name | Type | In PK |
|-----|------|------|-------|
| 1 | Code | Code[20] | Yes |
| 2 | Description | Text[100] | No |
| 10 | Skill | Blob (UTF-8 text) | No |
| 11 | Default | Boolean | No |
| 12 | Chat Provider | Enum "Bifrost LangModel Prov. ori" | No |
| 20 | Base URL | Text[250] | No |
| 21 | Model | Text[100] | No |
| 22 | Timeout Seconds | Integer | No |
| 23 | Max Tokens | Integer | No |
| 24 | Chat Path | Text[250] | No |
| 25 | Models Path | Text[250] | No |

The **Skill** field is not used by `LLM.Prompt.Complete`. It carries the skill text injected into the interactive Bifrost Chat only.

### Access Rules

- The caller must hold the **Chat Gate** permission set (`BIFROST Chat ori`, 10035398), which grants write access to the `Chat Gate ori` table. The implementation checks `WritePermission` on that table before it reads the request. Without it the call fails with `status: Error` and nothing is sent to the provider.
- The Chat Gate is not bundled into `BIFROST Bragi ori` or `BIFROST Bragi Rd ori`. An administrator assigns it explicitly, per user.
- A Bifrost licence is required. The implementation calls `AssertIsLicensed()` before it does any work.
- Only message version 1 is accepted. `AssertVersion1()` rejects anything else.

### Error Handling

| Condition | `error` |
|-----------|---------|
| Caller does not hold the Chat Gate permission set | `LLM prompt denied: missing 'Bifrost Chat' permission set.` |
| `prompt` missing or empty | `The "prompt" field is required.` |
| `roleCode` does not match a Bifrost Language Model | `Bifrost Language Model "%1" not found.` |
| Resolved language model has no configured provider | `No chat provider configured. Set up a Bifrost Language Model with a Chat Provider.` |
| Copilot provider is not enabled in Copilot & AI Capabilities | `Copilot is not enabled for Bifrost Chat. Ask your administrator to enable it in Copilot & AI Capabilities.` |
| A file or attachment is sent to the Copilot provider | `The Copilot provider does not support file attachments. Use an external provider (OpenAI, Azure OpenAI, Anthropic) for document processing.` |
| Provider returns an `error` property | The provider's own message. |
| Provider returns something that is not JSON | The raw provider text, returned as the error message. |
| Message version other than 1, or no valid licence | Raised by Bifrost Foundation before the implementation runs. |

Every error path returns HTTP 200 with `status: "Error"` in the body. The message type never raises an unhandled AL error for a configuration or input problem.

### Difference from the Interactive Bifrost Chat

| | LLM.Prompt.Complete | Bifrost Chat FactBox / Chat Focus |
|---|---|---|
| Tools | None | Full MCP tool server |
| System prompt | The caller's `system` only | Bootstrap, identity, language-model skill and the user's own system prompt |
| Response | Always text | May return tool calls, resolved over several turns |
| Conversation state | None | Kept for multi-turn conversations |
| Entry point | `tasks` API, queue, MCP `call_message_type` | Business Central client |
| Use case | Automated tasks and playbooks | Interactive work on a page |

---

## Permission Sets

| Permission Set | ID | Description |
|---|---|---|
| Chat Gate | 10035398 | Grants RIMD on the `Chat Gate ori` table. Required to invoke `LLM.Prompt.Complete` and to open the Bifrost Chat. Assign explicitly — it is in neither of the sets below. |
| Bifrost Bragi | 10035404 | Full access to the language models, the Bifrost Chat objects, the Copilot provider and the MCP tool server. Read-only on the Chat Gate. |
| Bifrost Bragi Read | 10035405 | Read-only access to the same objects. Language models can be inspected but not changed. |

---

## Related Documentation

- [Bragi Extensibility](Bragi_Extensibility.md) — adding a language model provider
- Bifrost Foundation, *API Reference* — the `tasks` endpoint, envelope and queue
- Bifrost Foundation, *Setup Reference* — Bifrost User Setup and the per-user system prompt
- Bifrost Foundation, *Extensibility Reference* — the `Message Type ori` enum and the `Msg Interface ori` contract
