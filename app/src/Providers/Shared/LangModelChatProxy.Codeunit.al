namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

using System.Text;

/// <summary>
/// Runs the LLM agentic tool loop for OpenAI-compatible chat providers. Calls the
/// Chat Completions API, dispatches tool_calls via the Bifrost MCP Tool Server,
/// feeds results back, and returns either a final reply or a tool_calls response
/// for the client to continue via ContinueWithToolResults.
/// </summary>
codeunit 10035412 "LangModel Chat Proxy ori"
{
    Access = Internal;

    var
        ToolServer: Codeunit "MCP Tool Server ori";
        ChatUtils: Codeunit "Bifrost Chat Utils ori";

    [NonDebuggable]
    internal procedure SendChatMessage(var Argument: Record "Bifrost Chat Argument ori" temporary; PayloadJson: Text; AuthHeaderName: Text): Text
    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        ApiClient: Codeunit "LangModel API Client ori";
        PayloadObject: JsonObject;
        Messages: JsonArray;
        OpenAITools: JsonArray;
        Model: Text;
        SystemPrompt: Text;
        ApiKey: SecretText;
        ChatUrl: Text;
    begin
        if not PayloadObject.ReadFrom(PayloadJson) then
            exit(BuildErrorResponse('Invalid payload JSON.'));

        ApiKey := Argument.GetApiKey();
        if ApiKey.IsEmpty() then
            exit(BuildErrorResponse('API key not configured.'));

        Model := GetTextProperty(PayloadObject, 'model');
        if Model = '' then
            Model := ProviderBase.GetModel(Argument, '');

        SystemPrompt := BuildSystemPrompt(PayloadObject, Argument);
        ParseMessages(PayloadObject, Messages);

        if SystemPrompt <> '' then
            AddSystemMessage(Messages, SystemPrompt);

        BuildToolDefinitions(OpenAITools);
        ChatUrl := ProviderBase.GetBaseUrl(Argument, '') + GetChatPath(Argument);

        exit(CallModelOnce(ApiClient, ChatUrl, AuthHeaderName, ApiKey,
            ProviderBase.GetTimeoutMs(Argument, 120000),
            ProviderBase.GetMaxTokens(Argument, 16384),
            Messages, OpenAITools, Model));
    end;

    [NonDebuggable]
    internal procedure ContinueWithToolResults(var Argument: Record "Bifrost Chat Argument ori" temporary; ConversationState: Text; ToolResultsJson: Text; AuthHeaderName: Text): Text
    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        ApiClient: Codeunit "LangModel API Client ori";
        StateObject: JsonObject;
        Messages: JsonArray;
        OpenAITools: JsonArray;
        MessagesToken: JsonToken;
        Model: Text;
        ApiKey: SecretText;
        ChatUrl: Text;
    begin
        ApiKey := Argument.GetApiKey();
        if ApiKey.IsEmpty() then
            exit(BuildErrorResponse('API key not configured.'));

        if not StateObject.ReadFrom(ConversationState) then
            exit(BuildErrorResponse('Invalid conversation state.'));

        Model := GetTextProperty(StateObject, 'model');
        if StateObject.Get('messages', MessagesToken) then
            Messages := MessagesToken.AsArray();
        BuildToolDefinitions(OpenAITools);

        AppendToolResultMessages(Messages, ToolResultsJson);
        ChatUrl := ProviderBase.GetBaseUrl(Argument, '') + GetChatPath(Argument);

        exit(CallModelOnce(ApiClient, ChatUrl, AuthHeaderName, ApiKey,
            ProviderBase.GetTimeoutMs(Argument, 120000),
            ProviderBase.GetMaxTokens(Argument, 16384),
            Messages, OpenAITools, Model));
    end;

    [NonDebuggable]
    local procedure CallModelOnce(var ApiClient: Codeunit "LangModel API Client ori"; ChatUrl: Text; AuthHeaderName: Text; ApiKey: SecretText; TimeoutMs: Integer; MaxTokens: Integer; var Messages: JsonArray; OpenAITools: JsonArray; Model: Text): Text
    var
        Response: JsonObject;
        RequestBody: JsonObject;
        ChoicesToken: JsonToken;
        FirstChoice: JsonToken;
        MessageObject: JsonObject;
        MessageToken: JsonToken;
        ToolCallsToken: JsonToken;
        AssistantMessage: JsonObject;
        UsageObject: JsonObject;
        UsageToken: JsonToken;
        Reply: Text;
        FinishReason: Text;
    begin
        ChatUtils.CompactOlderToolResults(Messages, 5, 500);
        ChatUtils.TrimMessageHistory(Messages, 80000);

        RequestBody.Add('model', Model);
        RequestBody.Add('max_completion_tokens', MaxTokens);
        RequestBody.Add('messages', Messages);
        if OpenAITools.Count() > 0 then
            RequestBody.Add('tools', OpenAITools);

        if not TrySendToModel(ApiClient, ChatUrl, AuthHeaderName, ApiKey, TimeoutMs, RequestBody, Response) then begin
            ApiClient.LogLastRequest();
            exit(BuildErrorResponse(GetLastErrorText()));
        end;
        ApiClient.LogLastRequest();

        if not Response.Get('choices', ChoicesToken) then
            exit(BuildErrorResponse('Empty response from AI model.'));
        if ChoicesToken.AsArray().Count() = 0 then
            exit(BuildErrorResponse('Empty response from AI model.'));

        ChoicesToken.AsArray().Get(0, FirstChoice);
        FirstChoice.AsObject().Get('message', MessageToken);
        MessageObject := MessageToken.AsObject();

        Clear(AssistantMessage);
        AssistantMessage.Add('role', 'assistant');
        CopyMessageContent(MessageObject, AssistantMessage);
        Messages.Add(AssistantMessage);

        if Response.Get('usage', UsageToken) then
            if UsageToken.IsObject() then
                UsageObject := UsageToken.AsObject();

        FinishReason := GetTextProperty(FirstChoice.AsObject(), 'finish_reason');
        if FinishReason = 'tool_calls' then begin
            if not MessageObject.Get('tool_calls', ToolCallsToken) then
                exit(BuildErrorResponse('Model signaled tool_calls but none present.'));
            exit(BuildToolCallsResponse(ToolCallsToken.AsArray(), Messages, Model, UsageObject));
        end;

        Reply := GetTextProperty(MessageObject, 'content');
        exit(BuildSuccessResponse(Reply, UsageObject));
    end;

    local procedure AddSystemMessage(var Messages: JsonArray; SystemPrompt: Text)
    var
        SystemMsg: JsonObject;
    begin
        SystemMsg.Add('role', 'system');
        SystemMsg.Add('content', SystemPrompt);
        Messages.Add(SystemMsg);
    end;

    local procedure CopyMessageContent(Source: JsonObject; var Target: JsonObject)
    var
        ContentToken: JsonToken;
        ToolCallsToken: JsonToken;
    begin
        if Source.Get('content', ContentToken) then
            Target.Add('content', ContentToken)
        else
            Target.Add('content', '');
        if Source.Get('tool_calls', ToolCallsToken) then
            Target.Add('tool_calls', ToolCallsToken);
    end;

    local procedure BuildSystemPrompt(PayloadObject: JsonObject; var Argument: Record "Bifrost Chat Argument ori" temporary) SystemPrompt: Text
    var
        PromptBuilder: TextBuilder;
        RecordContextToken: JsonToken;
        RecordContext: Text;
        UserPrompt: Text;
        RoleSkill: Text;
        ContextSkill: Text;
    begin
        PromptBuilder.Append(ToolServer.Bootstrap(''));

        if PayloadObject.Get('recordContext', RecordContextToken) then begin
            RecordContextToken.WriteTo(RecordContext);
            if RecordContext <> '' then begin
                PromptBuilder.AppendLine();
                PromptBuilder.AppendLine();
                PromptBuilder.AppendLine('RECORD CONTEXT:');
                PromptBuilder.AppendLine(RecordContext);
                PromptBuilder.AppendLine('When the user refers to the current page record, use its tableId and recordSystemId with get_records to fetch data.');
            end;
        end;

        RoleSkill := Argument.GetSkill();
        if RoleSkill <> '' then begin
            PromptBuilder.AppendLine();
            PromptBuilder.AppendLine();
            PromptBuilder.AppendLine('SKILL REFERENCE:');
            PromptBuilder.Append(RoleSkill);
        end;

        ContextSkill := GetTextProperty(PayloadObject, 'contextSkill');
        if ContextSkill <> '' then begin
            PromptBuilder.AppendLine();
            PromptBuilder.AppendLine();
            PromptBuilder.AppendLine('CONTEXT SKILL:');
            PromptBuilder.Append(ContextSkill);
        end;

        UserPrompt := Argument.GetUserPrompt();
        if UserPrompt <> '' then begin
            PromptBuilder.AppendLine();
            PromptBuilder.AppendLine();
            PromptBuilder.AppendLine('USER INSTRUCTIONS:');
            PromptBuilder.Append(UserPrompt);
        end;

        SystemPrompt := PromptBuilder.ToText();
    end;

    local procedure BuildToolDefinitions(var OpenAITools: JsonArray)
    var
        ServerTools: JsonArray;
        ToolToken: JsonToken;
        ToolObject: JsonObject;
        OpenAITool: JsonObject;
        FunctionDef: JsonObject;
        SchemaToken: JsonToken;
    begin
        ToolServer.ListTools(ServerTools);
        foreach ToolToken in ServerTools do begin
            ToolObject := ToolToken.AsObject();
            Clear(OpenAITool);
            Clear(FunctionDef);
            FunctionDef.Add('name', GetTextProperty(ToolObject, 'name'));
            FunctionDef.Add('description', GetTextProperty(ToolObject, 'description'));
            if ToolObject.Get('inputSchema', SchemaToken) then
                FunctionDef.Add('parameters', SchemaToken);
            OpenAITool.Add('type', 'function');
            OpenAITool.Add('function', FunctionDef);
            OpenAITools.Add(OpenAITool);
        end;
    end;

    [TryFunction]
    [NonDebuggable]
    local procedure TrySendToModel(var ApiClient: Codeunit "LangModel API Client ori"; ChatUrl: Text; AuthHeaderName: Text; ApiKey: SecretText; TimeoutMs: Integer; RequestBody: JsonObject; var Response: JsonObject)
    begin
        Response := ApiClient.SendToEndpoint(ChatUrl, AuthHeaderName, ApiKey, TimeoutMs, RequestBody);
    end;

    local procedure ParseMessages(PayloadObject: JsonObject; var Messages: JsonArray)
    var
        MessagesToken: JsonToken;
    begin
        if PayloadObject.Get('messages', MessagesToken) then
            if MessagesToken.IsArray() then
                Messages := MessagesToken.AsArray();
    end;

    local procedure AppendToolResultMessages(var Messages: JsonArray; ToolResultsJson: Text)
    var
        ResultsArray: JsonArray;
        ResultToken: JsonToken;
        ResultObj: JsonObject;
        ToolMsg: JsonObject;
        ResultText: Text;
    begin
        if not ResultsArray.ReadFrom(ToolResultsJson) then
            exit;
        foreach ResultToken in ResultsArray do begin
            if not ResultToken.IsObject() then
                continue;
            ResultObj := ResultToken.AsObject();
            Clear(ToolMsg);
            ToolMsg.Add('role', 'tool');
            ToolMsg.Add('tool_call_id', GetTextProperty(ResultObj, 'id'));
            ResultText := ChatUtils.TruncateContent(GetTextProperty(ResultObj, 'result'), 0);
            ToolMsg.Add('content', ResultText);
            Messages.Add(ToolMsg);
        end;
    end;

    local procedure BuildToolCallsResponse(ToolCallsArray: JsonArray; Messages: JsonArray; Model: Text; Usage: JsonObject) ResponseJson: Text
    var
        ResponseObject: JsonObject;
        NormalizedCalls: JsonArray;
        CallToken: JsonToken;
        CallObject: JsonObject;
        FunctionToken: JsonToken;
        FunctionObject: JsonObject;
        NormalizedCall: JsonObject;
        InputObject: JsonObject;
        StateObject: JsonObject;
        ArgumentsText: Text;
        ToolName: Text;
        StateText: Text;
    begin
        foreach CallToken in ToolCallsArray do begin
            if not CallToken.IsObject() then
                continue;
            CallObject := CallToken.AsObject();
            if not CallObject.Get('function', FunctionToken) then
                continue;
            FunctionObject := FunctionToken.AsObject();
            ToolName := GetTextProperty(FunctionObject, 'name');
            ArgumentsText := GetTextProperty(FunctionObject, 'arguments');

            Clear(NormalizedCall);
            NormalizedCall.Add('id', GetTextProperty(CallObject, 'id'));
            NormalizedCall.Add('name', ToolName);
            if (ArgumentsText <> '') and InputObject.ReadFrom(ArgumentsText) then begin
                InjectTableFormat(ToolName, InputObject);
                NormalizedCall.Add('arguments', InputObject);
            end;
            NormalizedCalls.Add(NormalizedCall);
        end;

        StateObject.Add('messages', Messages);
        StateObject.Add('model', Model);
        StateObject.WriteTo(StateText);

        ResponseObject.Add('type', 'tool_calls');
        ResponseObject.Add('toolCalls', NormalizedCalls);
        ResponseObject.Add('conversationState', StateText);
        if Usage.Keys().Count() > 0 then
            ResponseObject.Add('usage', Usage);
        ResponseObject.WriteTo(ResponseJson);
    end;

    local procedure BuildSuccessResponse(Reply: Text; Usage: JsonObject) ResponseJson: Text
    var
        ResponseObject: JsonObject;
    begin
        ResponseObject.Add('type', 'reply');
        ResponseObject.Add('reply', Reply);
        if Usage.Keys().Count() > 0 then
            ResponseObject.Add('usage', Usage);
        ResponseObject.WriteTo(ResponseJson);
    end;

    local procedure BuildErrorResponse(ErrorMessage: Text) ResponseJson: Text
    var
        ErrorObject: JsonObject;
    begin
        ErrorObject.Add('error', ErrorMessage);
        ErrorObject.WriteTo(ResponseJson);
    end;

    local procedure GetTextProperty(Source: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if Source.Get(PropertyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsText());
    end;

    local procedure InjectTableFormat(ToolName: Text; var Arguments: JsonObject)
    var
        FormatToken: JsonToken;
    begin
        if not (ToolName in ['get_records', 'get_record_ids', 'get_totals', 'find_entries',
                             'invoke_message_type', 'get_fields', 'search_tables']) then
            exit;
        if Arguments.Get('format', FormatToken) then
            exit;
        Arguments.Add('format', 'table');
    end;

    local procedure GetChatPath(var Argument: Record "Bifrost Chat Argument ori" temporary): Text
    begin
        if Argument."Chat Path" <> '' then
            exit(Argument."Chat Path");
        exit('/v1/chat/completions');
    end;
}
