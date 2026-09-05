# Bragi Extensibility

This document describes the **public extension point** of the Bifrost Bragi extension: adding a language model provider.

Anything not listed here is **internal** and may change between releases without notice. The package marks internal codeunits with `Access = Internal` and locks down the rest via the publisher's standard release policy.

---

## How to depend on Bifrost Bragi

Add both Bragi and the Bifrost Foundation it sits on to your extension's `app.json`. Bragi does not propagate its own dependency, so Foundation must be listed explicitly:

```json
"dependencies": [
    {
        "id": "f1722684-0c24-4022-a2e0-0f63154aca76",
        "name": "Bifrost Bragi",
        "publisher": "Origo",
        "version": "28.0.0.0"
    },
    {
        "id": "7505e808-6e52-4b96-a328-82573391297a",
        "name": "Bifrost Foundation",
        "publisher": "Origo",
        "version": "28.0.0.0"
    }
]
```

All objects in this guide live in the namespace `Origo.Bifrost.Bragi`.

---

## Extensibility surface at a glance

| Category | Items | Stability |
|---|---|---|
| Interfaces | `Bifrost LangModel Provider ori` | Stable contract — the single `Execute` signature never changes |
| Extensible enums | `Bifrost LangModel Prov. ori`, `Bifrost Chat Proc. Type ori` | Add new `value(...)` entries from your extension |
| Public tables | `Bifrost Language Model ori`, `Bifrost Chat Argument ori` | Extend `Bifrost Language Model ori` with a `tableextension`; the argument record is the interface parameter |
| Public codeunits | `Bifrost Chat Mgt ori`, `Bifrost Chat Transfer ori`, `MCP Tool Server ori` | Entry points for chat hosts and provider implementations |
| Control add-ins | `Bifrost Chat ori` | Hosted by the Bifrost Chat FactBox and the Chat Focus page |

---

## The provider contract

A language model provider is one codeunit implementing one interface:

```al
interface "Bifrost LangModel Provider ori"
{
    procedure Execute(var Argument: Record "Bifrost Chat Argument ori" temporary)
}
```

The signature never changes. The **operation** is carried in the `Procedure Type` field on the argument record, and new operations arrive as new values on the `Bifrost Chat Proc. Type ori` enum. A provider written against today's enum keeps compiling when operations are added — it simply does not answer the ones it does not know.

The caller resolves the implementation through the `Bifrost LangModel Prov. ori` enum, which is stored in the **Chat Provider** field on each `Bifrost Language Model ori` record. Its `DefaultImplementation` is `Bifrost LangModel None ori`, the disabled provider that reports "not configured" for everything.

### Registering the provider

```al
namespace Acme.Bifrost.Ollama;

using Origo.Bifrost.Bragi;

enumextension 50100 "Acme LangModel Prov." extends "Bifrost LangModel Prov. ori"
{
    value(50100; Ollama)
    {
        Caption = 'Ollama';
        Implementation = "Bifrost LangModel Provider ori" = "Acme Ollama Provider";
    }
}
```

That is the whole registration. The value appears in the **Chat Provider** field on the Bifrost Language Model card, and every call the base app makes for a language model with that provider lands in your codeunit.

---

## Operations to handle

`Bifrost Chat Proc. Type ori` (10035338) is grouped into config-dependent operations (10–17), provider metadata (100–116) and provider defaults (120–126).

Before each call the facade resets `Result Boolean` to `false`, `Result Integer` to `0`, and clears the result text and the error message. An operation your `case` does not cover therefore reads back as "not supported" — never as a stale value from a previous call. That is what makes partial implementations safe.

### Config-dependent operations

| Operation | Called by | Reads | Writes | Needed |
|---|---|---|---|---|
| `IsConfigured` (10) | Chat visibility gate; `LLM.Prompt.Complete` before it sends anything | Config fields, `GetApiKey` | `Result Boolean` | Always |
| `BuildConfigJson` (11) | Chat control add-in on start-up | Config fields | `SetResultText` (JSON) | For the chat UI |
| `SendChatMessage` (12) | `Bifrost Chat Mgt.SendChatMessage` | `GetPayload`, `GetSkill`, `GetUserPrompt`, `GetApiKey`, config | `SetResultText` (JSON) | For the chat UI |
| `ContinueWithToolResults` (13) | Chat control, after it has run the tool calls | `GetConversationState`, `GetToolResults`, `GetApiKey` | `SetResultText` (JSON) | Only when `SupportsSplitToolExecution` is true |
| `GetAvailableModels` (14) | **Get Models** on the language model card | Config, `GetApiKey` | `SetModels`, `Result Boolean` | Only when `SupportsModelSelection` is true |
| `TestConnection` (15) | **Test Connection** on the language model card | Config, `GetApiKey` | `Result Boolean`, `SetErrorMessage` | Recommended |
| `GetTokenUsage` (16) | Reserved — not called by the base app today | — | `Input Tokens`, `Output Tokens` | Optional |
| `CompletePrompt` (17) | The `LLM.Prompt.Complete` message type | `GetPayload`, config, `GetApiKey` | `SetResultText` (JSON) | For the message type |

A provider that answers only `IsConfigured`, `BuildConfigJson`, `SendChatMessage` and `CompletePrompt` is already usable: chat works, the message type works, and the card degrades gracefully because everything else reports "not supported".

### Provider metadata

| Operation | Called by | Writes |
|---|---|---|
| `GetProviderName` (100) | Diagnostics and the chat config | `SetResultText` |
| `RequiresApiKey` (101) | Chat config and the card's key dialog | `Result Boolean` |
| `GetApiKeyLabel` (102), `GetApiKeyInstruction` (103), `GetApiKeyPlaceholder` (104), `GetApiKeyDocsUrl` (105), `GetApiKeyDocsLinkText` (106), `GetServiceKeyDescription` (107) | Chat config and the card's key dialog | `SetResultText` |
| `HasServiceKeyPermission` (108) | Chat config — whether the user may save a shared key | `Result Boolean` |
| `GetMaxToolCount` (110) | Reserved — not called by the base app today | `Result Integer` |
| `SupportsSplitToolExecution` (111) | Chat config, as `supportsToolLoop` | `Result Boolean` |
| `SupportsModelSelection` (112) | **Get Models** on the card | `Result Boolean` |
| `SupportsToolCalling` (113) | Reserved — not called by the base app today | `Result Boolean` |
| `HasExternalEndpoint` (114) | Card field visibility and default seeding | `Result Boolean` |
| `RequiresChatPath` (115), `RequiresModelsPath` (116) | Card field visibility | `Result Boolean` |

`HasExternalEndpoint` is the switch that turns the endpoint half of the card on. Answer `false` for a provider that talks to Microsoft-managed resources — the Base URL, Model, Chat Path and Models Path fields then stay hidden and unvalidated.

### Provider defaults

| Operation | Called by | Writes |
|---|---|---|
| `GetDefaultBaseUrl` (120), `GetDefaultModel` (121) | Seeded into the language model when the provider is selected, and used to decide whether the field is mandatory | `SetResultText` |
| `GetDefaultTimeoutSeconds` (122), `GetDefaultMaxTokens` (123) | Seeded into the language model when the provider is selected | `Result Integer` |
| `GetContextWindowChars` (124) | Reserved — not called by the base app today | `Result Integer` |
| `GetDefaultSkillUrl` (125), `GetDefaultSkillText` (126) | **Load default skill** on the card | `SetResultText` |

---

## The argument record

`Bifrost Chat Argument ori` (10035337) is a `TableType = Temporary` record. Short values travel as fields; anything that can exceed a field length travels through accessor procedures backed by codeunit-scoped variables, so nothing large is ever written to the database.

### Fields the caller fills in

| Field | Type | Meaning |
|---|---|---|
| `Language Model SystemId` | Guid | Primary key — the `SystemId` of the resolved `Bifrost Language Model ori` record. |
| `Procedure Type` | Enum | The operation to perform. |
| `Base URL` | Text[250] | Endpoint root from the language model. |
| `Model` | Text[100] | Model name from the language model. |
| `Timeout Ms` | Integer | **Timeout Seconds** from the language model, already converted to milliseconds. |
| `Max Tokens` | Integer | Token ceiling from the language model. |
| `Chat Path` | Text[250] | Path appended to `Base URL` for completions. |
| `Models Path` | Text[250] | Path appended to `Base URL` for model discovery. |
| `Debug Mode` | Boolean | **Request Debug Mode** from the Bifrost setup — log full payloads when set. |

### Fields the provider writes

| Field | Type | Meaning |
|---|---|---|
| `Result Boolean` | Boolean | Answer to every boolean operation. |
| `Result Integer` | Integer | Answer to every numeric operation. |
| `Input Tokens`, `Output Tokens` | Integer | Answer to `GetTokenUsage`. |

### Text accessors

| Direction | Accessor | Carries |
|---|---|---|
| In | `GetApiKey()` | The resolved key — the caller's personal key, else the company service key. The setter is `[NonDebuggable]`; keep your own key handling `[NonDebuggable]` too. |
| In | `GetSkill()` | Skill text from the language model, for `SendChatMessage`. |
| In | `GetUserPrompt()` | The caller's own system prompt from Bifrost User Setup, for `SendChatMessage`. |
| In | `GetPayload()` | The request payload for `SendChatMessage` and `CompletePrompt`. |
| In | `GetConversationState()`, `GetToolResults()` | Split tool execution state for `ContinueWithToolResults`. |
| Out | `SetResultText()` | Every text and JSON answer. |
| Out | `SetErrorMessage()` | Human-readable failure for `TestConnection`. |
| Out | `SetModels()` | `Name/Value Buffer` of model ids and display names for `GetAvailableModels`. |

---

## Payload contracts

### `CompletePrompt`

Input, from `GetPayload()`:

```json
{
  "systemPrompt": "Extract structured data from text. Return valid JSON.",
  "messages": [{ "role": "user", "content": "Invoice #4521, total 1250.00" }],
  "files": [{ "data": "JVBERi0...", "mimeType": "application/pdf", "fileName": "Invoice.pdf" }]
}
```

`systemPrompt` and `files` are present only when the caller supplied them. Output, through `SetResultText()`, is a JSON object with either `reply` (or `text`) on success or `error` on failure. A provider that cannot process documents must return an `error` when `files` is present rather than silently dropping the attachment.

### `SendChatMessage`

Input carries `messages` (the full conversation, each entry `role` plus `content`), optionally `model`, `recordContext` (the `tableId` and `recordSystemId` of the page the FactBox is docked to) and `contextSkill`. The skill and the user's system prompt arrive separately through `GetSkill()` and `GetUserPrompt()`.

Output is one of three shapes:

```json
{ "type": "reply", "reply": "...", "toolTrace": [] }
{ "type": "tool_calls", "toolCalls": [{ "id": "...", "name": "get_records", "arguments": "{}" }], "conversationState": "..." }
{ "error": "..." }
```

`tool_calls` is only valid when `SupportsSplitToolExecution` reports `true`; the control add-in then runs each tool and calls back into `ContinueWithToolResults` with the state and the results. A provider that resolves its tool loop in-process returns `type: reply` directly and puts the calls it made into `toolTrace`.

### `BuildConfigJson`

A JSON object read by the chat control add-in. `provider`, `authMode`, `requiresApiKey` and a `labels` object of UI strings are the fields the control uses; the facade then overlays `canManageServiceKey`, `apiKeyLabel`, `apiKeyInstruction`, `apiKeyPlaceholder`, `apiKeyDocsUrl`, `apiKeyDocsLinkText`, `serviceKeyDescription` and `supportsToolLoop` from the metadata operations.

---

## The MCP tool server

`MCP Tool Server ori` (10035387) is `Access = Public` and `SingleInstance`. A provider uses it to give the model access to Business Central:

| Member | Purpose |
|---|---|
| `Bootstrap(RecordContext: Text): Text` | Builds the session system prompt — identity, company, memory and tool usage rules. Call once per chat turn. Pass the `recordContext` object from the payload, or an empty string. |
| `ListTools(var Tools: JsonArray)` | The tool registry in MCP shape: `name`, `description`, `inputSchema`. Convert to your provider's dialect. |
| `CallTool(ToolName: Text; Arguments: JsonObject; var ResultText: Text; var IsError: Boolean): Boolean` | Executes one tool inside its own `Codeunit.Run` scope. Returns `false` for an unknown tool; `IsError` reports a tool that ran and failed. |
| `GetToolCount(): Integer` | Number of registered tools. |
| `ClearSession()` | Drops the cached system prompt and the blob store. Call when a conversation is reset. |
| `BuildDynamicToolDefs(...)`, `SanitizeToolName(...)` | Build per-message-type tool definitions and turn a message type name into a valid tool name. |

Tool calls are written to the Bifrost request log. Register your own `Request Log Type ori` value with a `Request Log Masker ori` implementation if your provider logs requests that carry secrets.

---

## Complete example

A provider for a self-hosted Ollama endpoint that speaks the OpenAI chat-completions dialect, resolves its tool loop in-process against the Bifrost MCP tool server, and needs no API key.

**AcmeLangModelProv.EnumExt.al**

```al
namespace Acme.Bifrost.Ollama;

using Origo.Bifrost.Bragi;

/// <summary>
/// Registers the Ollama provider on the Bifrost language model provider enum.
/// </summary>
enumextension 50100 "Acme LangModel Prov." extends "Bifrost LangModel Prov. ori"
{
    value(50100; Ollama)
    {
        Caption = 'Ollama';
        Implementation = "Bifrost LangModel Provider ori" = "Acme Ollama Provider";
    }
}
```

**AcmeOllamaProvider.Codeunit.al**

```al
namespace Acme.Bifrost.Ollama;

using Origo.Bifrost.Bragi;

/// <summary>
/// Bifrost language model provider for a self-hosted Ollama endpoint that speaks the
/// OpenAI chat-completions dialect. Tool calls are resolved in-process against the
/// Bifrost MCP tool server, so the provider always returns a finished reply.
/// </summary>
codeunit 50100 "Acme Ollama Provider" implements "Bifrost LangModel Provider ori"
{
    var
        ToolServer: Codeunit "MCP Tool Server ori";
        NoBaseUrlErr: Label 'The Ollama base URL is not set on the language model.';
        InvalidPayloadErr: Label 'The chat payload was not valid JSON.';
        RequestFailedErr: Label 'The Ollama endpoint could not be reached.';
        NoReplyErr: Label 'The Ollama endpoint returned no message content.';
        FilesNotSupportedErr: Label 'This provider does not accept file attachments.';
        SplitToolLoopErr: Label 'This provider resolves tool calls in a single round trip.';
        ToolLimitErr: Label 'The model did not finish within the allowed number of tool rounds.';
        UnknownToolErr: Label 'Unknown tool: %1', Comment = '%1 = tool name';
        ThinkingLbl: Label 'Thinking...';
        InputPlaceholderLbl: Label 'Ask about your Business Central data...';
        SendBtnLbl: Label 'Send';
        ProviderNameTok: Label 'Ollama', Locked = true;
        DefaultBaseUrlTok: Label 'http://localhost:11434', Locked = true;
        DefaultModelTok: Label 'llama3.1', Locked = true;
        DefaultChatPathTok: Label '/v1/chat/completions', Locked = true;
        ModelsPathTok: Label '/api/tags', Locked = true;

    procedure Execute(var Argument: Record "Bifrost Chat Argument ori" temporary)
    var
        ProcType: Enum "Bifrost Chat Proc. Type ori";
    begin
        ProcType := Argument."Procedure Type";
        case ProcType of
            ProcType::IsConfigured:
                Argument."Result Boolean" := Argument."Base URL" <> '';
            ProcType::BuildConfigJson:
                Argument.SetResultText(BuildConfigJson());
            ProcType::SendChatMessage:
                Argument.SetResultText(RunChat(Argument, true));
            ProcType::CompletePrompt:
                Argument.SetResultText(RunChat(Argument, false));
            ProcType::ContinueWithToolResults:
                Argument.SetResultText(BuildErrorJson(SplitToolLoopErr));
            ProcType::TestConnection:
                RunTestConnection(Argument);
            ProcType::HasExternalEndpoint,
            ProcType::RequiresChatPath,
            ProcType::SupportsToolCalling:
                Argument."Result Boolean" := true;
            ProcType::GetAvailableModels,
            ProcType::RequiresApiKey,
            ProcType::RequiresModelsPath,
            ProcType::HasServiceKeyPermission,
            ProcType::SupportsModelSelection,
            ProcType::SupportsSplitToolExecution:
                Argument."Result Boolean" := false;
            ProcType::GetTokenUsage:
                begin
                    Argument."Input Tokens" := 0;
                    Argument."Output Tokens" := 0;
                end;
            ProcType::GetProviderName:
                Argument.SetResultText(ProviderNameTok);
            ProcType::GetDefaultBaseUrl:
                Argument.SetResultText(DefaultBaseUrlTok);
            ProcType::GetDefaultModel:
                Argument.SetResultText(DefaultModelTok);
            ProcType::GetDefaultTimeoutSeconds:
                Argument."Result Integer" := 120;
            ProcType::GetDefaultMaxTokens:
                Argument."Result Integer" := 4096;
            ProcType::GetContextWindowChars:
                Argument."Result Integer" := 32000;
            ProcType::GetMaxToolCount:
                Argument."Result Integer" := 20;
            ProcType::GetApiKeyLabel,
            ProcType::GetApiKeyInstruction,
            ProcType::GetApiKeyPlaceholder,
            ProcType::GetApiKeyDocsUrl,
            ProcType::GetApiKeyDocsLinkText,
            ProcType::GetServiceKeyDescription,
            ProcType::GetDefaultSkillUrl,
            ProcType::GetDefaultSkillText:
                Argument.SetResultText('');
        end;
    end;

    local procedure RunChat(var Argument: Record "Bifrost Chat Argument ori" temporary; WithTools: Boolean): Text
    var
        PayloadObject: JsonObject;
        ChoiceMessage: JsonObject;
        MessagesArray: JsonArray;
        ToolCalls: JsonArray;
        Iteration: Integer;
        ReplyText: Text;
    begin
        if Argument."Base URL" = '' then
            exit(BuildErrorJson(NoBaseUrlErr));
        if not PayloadObject.ReadFrom(Argument.GetPayload()) then
            exit(BuildErrorJson(InvalidPayloadErr));
        if HasFiles(PayloadObject) then
            exit(BuildErrorJson(FilesNotSupportedErr));

        MessagesArray := BuildMessages(Argument, PayloadObject, WithTools);

        for Iteration := 1 to 10 do begin
            Clear(ChoiceMessage);
            if not PostCompletion(Argument, MessagesArray, WithTools, ChoiceMessage) then
                exit(BuildErrorJson(RequestFailedErr));

            Clear(ToolCalls);
            if not HasToolCalls(ChoiceMessage, ToolCalls) then begin
                ReplyText := GetTextValue(ChoiceMessage, 'content');
                if ReplyText = '' then
                    exit(BuildErrorJson(NoReplyErr));
                exit(BuildReplyJson(ReplyText));
            end;

            MessagesArray.Add(ChoiceMessage);
            AppendToolResults(ToolCalls, MessagesArray);
        end;

        exit(BuildErrorJson(ToolLimitErr));
    end;

    local procedure PostCompletion(var Argument: Record "Bifrost Chat Argument ori" temporary; MessagesArray: JsonArray; WithTools: Boolean; var ChoiceMessage: JsonObject): Boolean
    var
        Client: HttpClient;
        RequestContent: HttpContent;
        ContentHeaders: HttpHeaders;
        ResponseMessage: HttpResponseMessage;
        RequestObject: JsonObject;
        ResponseObject: JsonObject;
        Tools: JsonArray;
        ChoicesToken: JsonToken;
        ChoiceToken: JsonToken;
        MessageToken: JsonToken;
        RequestText: Text;
        ResponseText: Text;
    begin
        RequestObject.Add('model', GetModel(Argument));
        RequestObject.Add('stream', false);
        RequestObject.Add('messages', MessagesArray);
        if Argument."Max Tokens" > 0 then
            RequestObject.Add('max_tokens', Argument."Max Tokens");
        if WithTools then begin
            Tools := BuildToolDefinitions();
            if Tools.Count() > 0 then
                RequestObject.Add('tools', Tools);
        end;
        RequestObject.WriteTo(RequestText);

        RequestContent.WriteFrom(RequestText);
        RequestContent.GetHeaders(ContentHeaders);
        ContentHeaders.Clear();
        ContentHeaders.Add('Content-Type', 'application/json');

        if Argument."Timeout Ms" > 0 then
            Client.Timeout := Argument."Timeout Ms";

        if not Client.Post(GetEndpoint(Argument), RequestContent, ResponseMessage) then
            exit(false);
        ResponseMessage.Content.ReadAs(ResponseText);
        if not ResponseMessage.IsSuccessStatusCode then
            exit(false);
        if not ResponseObject.ReadFrom(ResponseText) then
            exit(false);
        if not ResponseObject.Get('choices', ChoicesToken) then
            exit(false);
        if not ChoicesToken.IsArray() then
            exit(false);
        if not ChoicesToken.AsArray().Get(0, ChoiceToken) then
            exit(false);
        if not ChoiceToken.AsObject().Get('message', MessageToken) then
            exit(false);
        ChoiceMessage := MessageToken.AsObject();
        exit(true);
    end;

    local procedure BuildMessages(var Argument: Record "Bifrost Chat Argument ori" temporary; PayloadObject: JsonObject; WithTools: Boolean) MessagesArray: JsonArray
    var
        SystemMessage: JsonObject;
        MessagesToken: JsonToken;
        MessageToken: JsonToken;
    begin
        SystemMessage.Add('role', 'system');
        SystemMessage.Add('content', BuildSystemPrompt(Argument, PayloadObject, WithTools));
        MessagesArray.Add(SystemMessage);

        if PayloadObject.Get('messages', MessagesToken) then
            if MessagesToken.IsArray() then
                foreach MessageToken in MessagesToken.AsArray() do
                    MessagesArray.Add(MessageToken);
    end;

    local procedure BuildSystemPrompt(var Argument: Record "Bifrost Chat Argument ori" temporary; PayloadObject: JsonObject; WithTools: Boolean): Text
    var
        PromptBuilder: TextBuilder;
        RecordContextToken: JsonToken;
        RecordContext: Text;
    begin
        if not WithTools then
            exit(GetTextValue(PayloadObject, 'systemPrompt'));

        if PayloadObject.Get('recordContext', RecordContextToken) then
            RecordContextToken.WriteTo(RecordContext);

        PromptBuilder.Append(ToolServer.Bootstrap(RecordContext));
        if Argument.GetSkill() <> '' then begin
            PromptBuilder.AppendLine();
            PromptBuilder.AppendLine(Argument.GetSkill());
        end;
        if Argument.GetUserPrompt() <> '' then begin
            PromptBuilder.AppendLine();
            PromptBuilder.AppendLine(Argument.GetUserPrompt());
        end;
        exit(PromptBuilder.ToText());
    end;

    local procedure BuildToolDefinitions() Tools: JsonArray
    var
        ServerTools: JsonArray;
        ToolToken: JsonToken;
        SchemaToken: JsonToken;
        ToolObject: JsonObject;
        FunctionObject: JsonObject;
        WrapperObject: JsonObject;
        EmptySchema: JsonObject;
    begin
        ToolServer.ListTools(ServerTools);
        foreach ToolToken in ServerTools do begin
            ToolObject := ToolToken.AsObject();
            Clear(FunctionObject);
            Clear(WrapperObject);
            FunctionObject.Add('name', GetTextValue(ToolObject, 'name'));
            FunctionObject.Add('description', GetTextValue(ToolObject, 'description'));
            if ToolObject.Get('inputSchema', SchemaToken) then
                FunctionObject.Add('parameters', SchemaToken.AsObject())
            else begin
                Clear(EmptySchema);
                EmptySchema.Add('type', 'object');
                FunctionObject.Add('parameters', EmptySchema);
            end;
            WrapperObject.Add('type', 'function');
            WrapperObject.Add('function', FunctionObject);
            Tools.Add(WrapperObject);
        end;
    end;

    local procedure HasToolCalls(ChoiceMessage: JsonObject; var ToolCalls: JsonArray): Boolean
    var
        ToolCallsToken: JsonToken;
    begin
        if not ChoiceMessage.Get('tool_calls', ToolCallsToken) then
            exit(false);
        if not ToolCallsToken.IsArray() then
            exit(false);
        ToolCalls := ToolCallsToken.AsArray();
        exit(ToolCalls.Count() > 0);
    end;

    local procedure AppendToolResults(ToolCalls: JsonArray; var MessagesArray: JsonArray)
    var
        ToolCallToken: JsonToken;
        FunctionToken: JsonToken;
        ToolCallObject: JsonObject;
        FunctionObject: JsonObject;
        ArgumentsObject: JsonObject;
        ResultMessage: JsonObject;
        ToolName: Text;
        ArgumentsText: Text;
        ResultText: Text;
        IsError: Boolean;
    begin
        foreach ToolCallToken in ToolCalls do begin
            ToolCallObject := ToolCallToken.AsObject();
            if ToolCallObject.Get('function', FunctionToken) then begin
                FunctionObject := FunctionToken.AsObject();
                ToolName := GetTextValue(FunctionObject, 'name');
                ArgumentsText := GetTextValue(FunctionObject, 'arguments');
                Clear(ArgumentsObject);
                if ArgumentsText <> '' then
                    if not ArgumentsObject.ReadFrom(ArgumentsText) then
                        Clear(ArgumentsObject);
                if not ToolServer.CallTool(ToolName, ArgumentsObject, ResultText, IsError) then
                    ResultText := StrSubstNo(UnknownToolErr, ToolName);
                Clear(ResultMessage);
                ResultMessage.Add('role', 'tool');
                ResultMessage.Add('tool_call_id', GetTextValue(ToolCallObject, 'id'));
                ResultMessage.Add('content', ResultText);
                MessagesArray.Add(ResultMessage);
            end;
        end;
    end;

    local procedure RunTestConnection(var Argument: Record "Bifrost Chat Argument ori" temporary)
    var
        Client: HttpClient;
        ResponseMessage: HttpResponseMessage;
    begin
        if Argument."Base URL" = '' then begin
            Argument."Result Boolean" := false;
            Argument.SetErrorMessage(NoBaseUrlErr);
            exit;
        end;
        if Argument."Timeout Ms" > 0 then
            Client.Timeout := Argument."Timeout Ms";
        if not Client.Get(Argument."Base URL" + ModelsPathTok, ResponseMessage) then begin
            Argument."Result Boolean" := false;
            Argument.SetErrorMessage(RequestFailedErr);
            exit;
        end;
        Argument."Result Boolean" := ResponseMessage.IsSuccessStatusCode;
        if not Argument."Result Boolean" then
            Argument.SetErrorMessage(RequestFailedErr);
    end;

    local procedure BuildConfigJson() ConfigText: Text
    var
        Config: JsonObject;
        Labels: JsonObject;
    begin
        Labels.Add('thinking', ThinkingLbl);
        Labels.Add('inputPlaceholder', InputPlaceholderLbl);
        Labels.Add('sendBtn', SendBtnLbl);

        Config.Add('provider', ProviderNameTok);
        Config.Add('authMode', 'none');
        Config.Add('requiresApiKey', false);
        Config.Add('labels', Labels);
        Config.WriteTo(ConfigText);
    end;

    local procedure BuildReplyJson(ReplyText: Text) ResponseText: Text
    var
        Response: JsonObject;
    begin
        Response.Add('type', 'reply');
        Response.Add('reply', ReplyText);
        Response.WriteTo(ResponseText);
    end;

    local procedure BuildErrorJson(ErrorMessage: Text) ResponseText: Text
    var
        Response: JsonObject;
    begin
        Response.Add('error', ErrorMessage);
        Response.WriteTo(ResponseText);
    end;

    local procedure HasFiles(PayloadObject: JsonObject): Boolean
    var
        FilesToken: JsonToken;
    begin
        if not PayloadObject.Get('files', FilesToken) then
            exit(false);
        exit(FilesToken.IsArray() and (FilesToken.AsArray().Count() > 0));
    end;

    local procedure GetEndpoint(var Argument: Record "Bifrost Chat Argument ori" temporary): Text
    var
        Path: Text;
    begin
        Path := Argument."Chat Path";
        if Path = '' then
            Path := DefaultChatPathTok;
        exit(Argument."Base URL" + Path);
    end;

    local procedure GetModel(var Argument: Record "Bifrost Chat Argument ori" temporary): Text
    begin
        if Argument.Model <> '' then
            exit(Argument.Model);
        exit(DefaultModelTok);
    end;

    local procedure GetTextValue(Source: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if Source.Get(PropertyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsText());
        exit('');
    end;
}
```

### Sending an API key

The example above needs no key, so it reports `RequiresApiKey = false` and never touches `GetApiKey()`. A provider that authenticates with a bearer token reads the resolved key from the argument record and builds the header as a `SecretText`, so the value never appears in a debugger or a request log:

```al
[NonDebuggable]
local procedure AddAuthorization(var Argument: Record "Bifrost Chat Argument ori" temporary; var Client: HttpClient)
var
    ApiKeySecret: SecretText;
begin
    if Argument.GetApiKey() = '' then
        exit;
    ApiKeySecret := Argument.GetApiKey();
    Client.DefaultRequestHeaders.Add('Authorization', SecretStrSubstNo('Bearer %1', ApiKeySecret));
end;
```

Mark every procedure that handles the key `[NonDebuggable]`, and answer `RequiresApiKey` with `true` so the chat control shows the key dialog. The base app stores what the user types — personal keys under `Bifrost_Chat_Usr_<SystemId>_<user security id>` and shared keys under `Bifrost_Chat_Svc_<SystemId>`, both in Isolated Storage with company scope — and hands the resolved value back through `GetApiKey()`.

---

## Extending the language model record

Provider-specific settings belong on a `tableextension` over `Bifrost Language Model ori` in your own ID range:

```al
namespace Acme.Bifrost.Ollama;

using Origo.Bifrost.Bragi;

/// <summary>
/// Adds the Ollama keep-alive window to the Bifrost language model record.
/// </summary>
tableextension 50100 "Acme Ollama Language Model" extends "Bifrost Language Model ori"
{
    fields
    {
        field(50100; "Ollama Keep Alive Minutes"; Integer)
        {
            Caption = 'Ollama Keep Alive Minutes';
            DataClassification = CustomerContent;
            MinValue = 0;
        }
    }
}
```

Read the field inside `Execute` with `BifrostLanguageModel.GetBySystemId(Argument."Language Model SystemId")` — that is what the `Language Model SystemId` field on the argument record is for.

---

## Checklist

1. Implement `Bifrost LangModel Provider ori` in one codeunit, with a `case` on `Argument."Procedure Type"`.
2. Answer `IsConfigured` honestly — it is the gate for both the chat UI and `LLM.Prompt.Complete`.
3. Handle `CompletePrompt` if you want the message type to work with your provider, and `SendChatMessage` if you want the chat UI to work.
4. Return `error` in your JSON rather than raising an AL error; the callers turn that into a clean `status: Error` response.
5. Register the value on `Bifrost LangModel Prov. ori` with an `enumextension` in your own ID range.
6. Mark every procedure that touches the API key `[NonDebuggable]`.
7. Put provider-specific settings on a `tableextension` over `Bifrost Language Model ori`, never on new field numbers inside Bragi's range.

---

## Stability commitments

- **The interface**: `Execute(var Argument: Record "Bifrost Chat Argument ori" temporary)` is the permanent signature. New capability arrives as new `Bifrost Chat Proc. Type ori` values, never as a new procedure.
- **The argument record**: new fields and new accessor procedures may be added; existing field numbers, field types and accessor signatures are preserved across minor versions.
- **The provider enum**: Bragi owns its allocated ordinals only. Add your values from your own ID range.
- **`MCP Tool Server ori`**: the members listed above are part of the surface. The tool registry itself is data — tool names and schemas change as message types are added.
- **Internal codeunits**: `Copilot LangModel Prov. ori`, `Copilot Chat Proxy ori`, `MCP Tool Executor ori` and the message-type implementations are internal. Do not call them and do not subscribe to their events.

If you need an extensibility hook that is not listed here, open an issue in the Bifrost Bragi repository describing the use case rather than depending on internal members.

---

## Related Documentation

- [Chat Message Types](Chat_Message_Types.md) — the `LLM.Prompt.Complete` contract
- Bifrost Foundation, *Extensibility Reference* — the `Message Type ori` enum, the `Msg Interface ori` contract and the `Request Log Type ori` enum
- Bifrost Foundation, *Setup Reference* — Bifrost User Setup and the per-user system prompt
