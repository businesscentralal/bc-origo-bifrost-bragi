namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

using System.Text;

/// <summary>
/// Runs the Anthropic agentic tool loop using the Messages API.
/// Converts between the Bifrost MCP tool definitions and Anthropic's input_schema format,
/// and handles the content-block response structure (text/tool_use).
/// </summary>
codeunit 10035417 "Anthropic LangModel Proxy ori"
{
    Access = Internal;

    var
        ToolServer: Codeunit "MCP Tool Server ori";
        ChatUtils: Codeunit "Bifrost Chat Utils ori";
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        AnthropicVersionTok: Label '2023-06-01', Locked = true;
        MessagesPathTok: Label '%1/v1/messages', Locked = true;
        ModelsPathTok: Label '%1/v1/models?limit=100', Locked = true;
        DefaultBaseUrlTok: Label 'https://api.anthropic.com', Locked = true;
        ServiceNameTok: Label 'LLM', Locked = true;
        CallFailedErr: Label 'Could not reach the Anthropic API. %1', Comment = '%1 = error detail, is-IS=Náði ekki sambandi við Anthropic API. %1';
        ApiStatusErr: Label 'Anthropic API returned status %1. %2', Comment = '%1 = status code, %2 = detail, is-IS=Anthropic API skilaði stöðu %1. %2';
        InvalidResponseErr: Label 'Received an invalid response from the Anthropic API.', Comment = 'is-IS=Ógilt svar barst frá Anthropic API.';

    [NonDebuggable]
    internal procedure SendChatMessage(var Argument: Record "Bifrost Chat Argument ori" temporary; PayloadJson: Text): Text
    var
        PayloadObject: JsonObject;
        Messages: JsonArray;
        AnthropicTools: JsonArray;
        Model: Text;
        SystemPrompt: Text;
        ApiKey: SecretText;
    begin
        if not PayloadObject.ReadFrom(PayloadJson) then
            exit(BuildErrorResponse('Invalid payload JSON.'));

        ApiKey := Argument.GetApiKey();
        if ApiKey.IsEmpty() then
            exit(BuildErrorResponse('API key not configured.'));

        Model := GetText(PayloadObject, 'model');
        if Model = '' then
            Model := ProviderBase.GetModel(Argument, 'claude-sonnet-4-6');

        SystemPrompt := BuildSystemPrompt(PayloadObject, Argument);
        ParseMessages(PayloadObject, Messages);
        BuildToolDefinitions(AnthropicTools);

        exit(CallAnthropicOnce(
            Messages, AnthropicTools, Model, SystemPrompt, ApiKey,
            ProviderBase.GetBaseUrl(Argument, DefaultBaseUrlTok),
            ProviderBase.GetTimeoutMs(Argument, 300000),
            ProviderBase.GetMaxTokens(Argument, 16384)));
    end;

    [NonDebuggable]
    internal procedure CompletePrompt(var Argument: Record "Bifrost Chat Argument ori" temporary; PayloadJson: Text): Text
    var
        PayloadObject: JsonObject;
        Messages: JsonArray;
        MessagesToken: JsonToken;
        MessageToken: JsonToken;
        Model: Text;
        SystemPrompt: Text;
        ApiKey: SecretText;
    begin
        if not PayloadObject.ReadFrom(PayloadJson) then
            exit(BuildErrorResponse('Invalid payload JSON.'));

        ApiKey := Argument.GetApiKey();
        if ApiKey.IsEmpty() then
            exit(BuildErrorResponse('API key not configured.'));

        Model := ProviderBase.GetModel(Argument, 'claude-sonnet-4-6');
        SystemPrompt := GetText(PayloadObject, 'systemPrompt');

        if PayloadObject.Get('messages', MessagesToken) then
            if MessagesToken.IsArray() then
                foreach MessageToken in MessagesToken.AsArray() do
                    Messages.Add(MessageToken);

        AttachFilesToAnthropicMessages(PayloadObject, Messages);

        // Call API directly — skip TrimMessageHistory which would discard large file content
        exit(CallAnthropicDirect(
            Messages, Model, SystemPrompt, ApiKey,
            ProviderBase.GetBaseUrl(Argument, DefaultBaseUrlTok),
            ProviderBase.GetTimeoutMs(Argument, 300000),
            ProviderBase.GetMaxTokens(Argument, 16384)));
    end;

    [NonDebuggable]
    local procedure CallAnthropicDirect(var Messages: JsonArray; Model: Text; SystemPrompt: Text; ApiKey: SecretText; BaseUrl: Text; TimeoutMs: Integer; MaxTokens: Integer): Text
    var
        Response: JsonObject;
        RequestBody: JsonObject;
        UsageObject: JsonObject;
        UsageToken: JsonToken;
        Reply: Text;
    begin
        RequestBody.Add('model', Model);
        RequestBody.Add('max_tokens', MaxTokens);
        if SystemPrompt <> '' then
            RequestBody.Add('system', SystemPrompt);
        RequestBody.Add('messages', Messages);

        if not TrySendMessages(BaseUrl, ApiKey, TimeoutMs, RequestBody, Response) then
            exit(BuildErrorResponse(GetLastErrorText()));

        if Response.Get('usage', UsageToken) then
            if UsageToken.IsObject() then
                UsageObject := UsageToken.AsObject();

        Reply := ExtractText(Response);
        exit(BuildSuccessResponse(Reply, UsageObject));
    end;

    local procedure AttachFilesToAnthropicMessages(PayloadObject: JsonObject; var Messages: JsonArray)
    var
        FilesToken: JsonToken;
        FilesArray: JsonArray;
        FileToken: JsonToken;
        FileObj: JsonObject;
        ContentArray: JsonArray;
        TextBlock: JsonObject;
        FileBlock: JsonObject;
        Source: JsonObject;
        LastToken: JsonToken;
        LastMessage: JsonObject;
        NewMessage: JsonObject;
        UserText: Text;
        MimeType: Text;
        LastIndex: Integer;
    begin
        if not PayloadObject.Get('files', FilesToken) then
            exit;
        FilesArray := FilesToken.AsArray();
        if FilesArray.Count() = 0 then
            exit;

        LastIndex := Messages.Count() - 1;
        if LastIndex < 0 then
            exit;
        Messages.Get(LastIndex, LastToken);
        if not LastToken.IsObject() then
            exit;
        LastMessage := LastToken.AsObject();

        UserText := GetText(LastMessage, 'content');
        foreach FileToken in FilesArray do begin
            if not FileToken.IsObject() then
                continue;
            FileObj := FileToken.AsObject();
            MimeType := GetText(FileObj, 'mimeType');
            Clear(Source);
            Source.Add('type', 'base64');
            Source.Add('media_type', MimeType);
            Source.Add('data', GetText(FileObj, 'data'));
            Clear(FileBlock);
            if MimeType.StartsWith('image/') then
                FileBlock.Add('type', 'image')
            else
                FileBlock.Add('type', 'document');
            FileBlock.Add('source', Source);
            ContentArray.Add(FileBlock);
        end;

        TextBlock.Add('type', 'text');
        TextBlock.Add('text', UserText);
        ContentArray.Add(TextBlock);

        // Replace the last message — JsonArray.Get returns a copy
        Messages.RemoveAt(LastIndex);
        NewMessage.Add('role', 'user');
        NewMessage.Add('content', ContentArray);
        Messages.Add(NewMessage);
    end;

    [NonDebuggable]
    internal procedure ContinueWithToolResults(var Argument: Record "Bifrost Chat Argument ori" temporary; ConversationState: Text; ToolResultsJson: Text): Text
    var
        StateObject: JsonObject;
        Messages: JsonArray;
        AnthropicTools: JsonArray;
        AnthropicResults: JsonArray;
        UserMessage: JsonObject;
        MessagesToken: JsonToken;
        Model: Text;
        SystemPrompt: Text;
        ApiKey: SecretText;
    begin
        ApiKey := Argument.GetApiKey();
        if ApiKey.IsEmpty() then
            exit(BuildErrorResponse('API key not configured.'));

        if not StateObject.ReadFrom(ConversationState) then
            exit(BuildErrorResponse('Invalid conversation state.'));

        Model := GetText(StateObject, 'model');
        SystemPrompt := GetText(StateObject, 'systemPrompt');
        if StateObject.Get('messages', MessagesToken) then
            Messages := MessagesToken.AsArray();
        BuildToolDefinitions(AnthropicTools);

        ConvertToolResults(ToolResultsJson, AnthropicResults);
        UserMessage.Add('role', 'user');
        UserMessage.Add('content', AnthropicResults);
        Messages.Add(UserMessage);

        exit(CallAnthropicOnce(
            Messages, AnthropicTools, Model, SystemPrompt, ApiKey,
            ProviderBase.GetBaseUrl(Argument, DefaultBaseUrlTok),
            ProviderBase.GetTimeoutMs(Argument, 300000),
            ProviderBase.GetMaxTokens(Argument, 16384)));
    end;

    [NonDebuggable]
    local procedure CallAnthropicOnce(var Messages: JsonArray; AnthropicTools: JsonArray; Model: Text; SystemPrompt: Text; ApiKey: SecretText; BaseUrl: Text; TimeoutMs: Integer; MaxTokens: Integer): Text
    var
        Response: JsonObject;
        RequestBody: JsonObject;
        ContentToken: JsonToken;
        AssistantMessage: JsonObject;
        UsageObject: JsonObject;
        UsageToken: JsonToken;
        Reply: Text;
    begin
        ChatUtils.CompactOlderToolResults(Messages, 5, 500);
        ChatUtils.TrimMessageHistory(Messages, 160000);
        RemoveOrphanedToolMessages(Messages);

        RequestBody.Add('model', Model);
        RequestBody.Add('max_tokens', MaxTokens);
        if SystemPrompt <> '' then
            RequestBody.Add('system', SystemPrompt);
        RequestBody.Add('messages', Messages);
        if AnthropicTools.Count() > 0 then
            RequestBody.Add('tools', AnthropicTools);

        if not TrySendMessages(BaseUrl, ApiKey, TimeoutMs, RequestBody, Response) then
            exit(BuildErrorResponse(GetLastErrorText()));

        if not Response.Get('content', ContentToken) then
            exit(BuildErrorResponse('Empty response from AI model.'));

        Clear(AssistantMessage);
        AssistantMessage.Add('role', 'assistant');
        AssistantMessage.Add('content', ContentToken);
        Messages.Add(AssistantMessage);

        if Response.Get('usage', UsageToken) then
            if UsageToken.IsObject() then
                UsageObject := UsageToken.AsObject();

        if GetText(Response, 'stop_reason') = 'tool_use' then
            exit(BuildToolCallsResponse(ContentToken.AsArray(), Messages, Model, SystemPrompt, UsageObject));

        Reply := ExtractText(Response);
        exit(BuildSuccessResponse(Reply, UsageObject));
    end;

    [TryFunction]
    [NonDebuggable]
    local procedure TrySendMessages(BaseUrl: Text; ApiKey: SecretText; TimeoutMs: Integer; RequestBody: JsonObject; var Response: JsonObject)
    begin
        Response := DoSendMessages(BaseUrl, ApiKey, TimeoutMs, RequestBody);
    end;

    [NonDebuggable]
    local procedure DoSendMessages(BaseUrl: Text; ApiKey: SecretText; TimeoutMs: Integer; RequestBody: JsonObject) Response: JsonObject
    var
        HttpClientVar: HttpClient;
        HttpContent: HttpContent;
        HttpResponse: HttpResponseMessage;
        ContentHeaders: HttpHeaders;
        DefaultHeaders: HttpHeaders;
        RequestUrl: Text;
        RequestText: Text;
        ResponseText: Text;
        StartTime: DateTime;
    begin
        RequestBody.WriteTo(RequestText);
        HttpContent.WriteFrom(RequestText);
        HttpContent.GetHeaders(ContentHeaders);
        if ContentHeaders.Contains('Content-Type') then
            ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'application/json');

        DefaultHeaders := HttpClientVar.DefaultRequestHeaders();
        DefaultHeaders.Add('x-api-key', ApiKey);
        DefaultHeaders.Add('anthropic-version', AnthropicVersionTok);
        HttpClientVar.Timeout(TimeoutMs);

        RequestUrl := StrSubstNo(MessagesPathTok, BaseUrl);
        StartTime := CurrentDateTime();
        if not HttpClientVar.Post(RequestUrl, HttpContent, HttpResponse) then
            Error(CallFailedErr, GetLastErrorText());

        HttpResponse.Content.ReadAs(ResponseText);

        if not HttpResponse.IsSuccessStatusCode() then
            Error(ApiStatusErr, Format(HttpResponse.HttpStatusCode()), GetErrorDetail(ResponseText));

        if not Response.ReadFrom(ResponseText) then
            Error(InvalidResponseErr);

        LogApiCall('messages', 'POST', RequestUrl,
            HttpResponse.HttpStatusCode(), CurrentDateTime() - StartTime, RequestText, ResponseText);
    end;

    /// <summary>
    /// Lists models from the Anthropic Models API.
    /// </summary>
    [NonDebuggable]
    internal procedure ListModels(BaseUrl: Text; ApiKey: SecretText) Models: JsonArray
    var
        HttpClientVar: HttpClient;
        HttpResponse: HttpResponseMessage;
        DefaultHeaders: HttpHeaders;
        Response: JsonObject;
        DataToken: JsonToken;
        RequestUrl: Text;
        ResponseText: Text;
        StartTime: DateTime;
    begin
        DefaultHeaders := HttpClientVar.DefaultRequestHeaders();
        DefaultHeaders.Add('x-api-key', ApiKey);
        DefaultHeaders.Add('anthropic-version', AnthropicVersionTok);

        RequestUrl := StrSubstNo(ModelsPathTok, BaseUrl);
        StartTime := CurrentDateTime();
        if not HttpClientVar.Get(RequestUrl, HttpResponse) then
            Error(CallFailedErr, GetLastErrorText());

        HttpResponse.Content.ReadAs(ResponseText);

        if not HttpResponse.IsSuccessStatusCode() then
            Error(ApiStatusErr, Format(HttpResponse.HttpStatusCode()), GetErrorDetail(ResponseText));

        if not Response.ReadFrom(ResponseText) then
            Error(InvalidResponseErr);

        if Response.Get('data', DataToken) then
            if DataToken.IsArray() then
                Models := DataToken.AsArray();

        LogApiCall('models', 'GET', RequestUrl,
            HttpResponse.HttpStatusCode(), CurrentDateTime() - StartTime, '', ResponseText);
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

        ContextSkill := GetText(PayloadObject, 'contextSkill');
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

    local procedure BuildToolDefinitions(var AnthropicTools: JsonArray)
    var
        ServerTools: JsonArray;
        ToolToken: JsonToken;
        ToolObject: JsonObject;
        AnthropicTool: JsonObject;
        SchemaToken: JsonToken;
    begin
        ToolServer.ListTools(ServerTools);
        foreach ToolToken in ServerTools do begin
            ToolObject := ToolToken.AsObject();
            Clear(AnthropicTool);
            AnthropicTool.Add('name', GetText(ToolObject, 'name'));
            AnthropicTool.Add('description', GetText(ToolObject, 'description'));
            if ToolObject.Get('inputSchema', SchemaToken) then
                AnthropicTool.Add('input_schema', SchemaToken);
            AnthropicTools.Add(AnthropicTool);
        end;
    end;

    local procedure ParseMessages(PayloadObject: JsonObject; var Messages: JsonArray)
    var
        MessagesToken: JsonToken;
    begin
        if PayloadObject.Get('messages', MessagesToken) then
            if MessagesToken.IsArray() then
                Messages := MessagesToken.AsArray();
    end;

    local procedure ConvertToolResults(ToolResultsJson: Text; var AnthropicResults: JsonArray)
    var
        ResultsArray: JsonArray;
        ResultToken: JsonToken;
        ResultObj: JsonObject;
        AnthropicResult: JsonObject;
        ResultText: Text;
    begin
        if not ResultsArray.ReadFrom(ToolResultsJson) then
            exit;
        foreach ResultToken in ResultsArray do begin
            if not ResultToken.IsObject() then
                continue;
            ResultObj := ResultToken.AsObject();
            Clear(AnthropicResult);
            AnthropicResult.Add('type', 'tool_result');
            AnthropicResult.Add('tool_use_id', GetText(ResultObj, 'id'));
            ResultText := ChatUtils.TruncateContent(GetText(ResultObj, 'result'), 0);
            AnthropicResult.Add('content', ResultText);
            if GetBool(ResultObj, 'isError') then
                AnthropicResult.Add('is_error', true);
            AnthropicResults.Add(AnthropicResult);
        end;
    end;

    local procedure BuildToolCallsResponse(ContentArray: JsonArray; Messages: JsonArray; Model: Text; SystemPrompt: Text; Usage: JsonObject) ResponseJson: Text
    var
        ResponseObject: JsonObject;
        ToolCalls: JsonArray;
        StateObject: JsonObject;
        BlockToken: JsonToken;
        BlockObject: JsonObject;
        ToolCall: JsonObject;
        InputToken: JsonToken;
        StateText: Text;
    begin
        foreach BlockToken in ContentArray do begin
            if not BlockToken.IsObject() then
                continue;
            BlockObject := BlockToken.AsObject();
            if GetText(BlockObject, 'type') <> 'tool_use' then
                continue;
            Clear(ToolCall);
            ToolCall.Add('id', GetText(BlockObject, 'id'));
            ToolCall.Add('name', GetText(BlockObject, 'name'));
            if BlockObject.Get('input', InputToken) then
                ToolCall.Add('arguments', InputToken);
            ToolCalls.Add(ToolCall);
        end;

        StateObject.Add('messages', Messages);
        StateObject.Add('model', Model);
        StateObject.Add('systemPrompt', SystemPrompt);
        StateObject.WriteTo(StateText);

        ResponseObject.Add('type', 'tool_calls');
        ResponseObject.Add('toolCalls', ToolCalls);
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

    local procedure ExtractText(Response: JsonObject) ResultText: Text
    var
        ContentToken: JsonToken;
        BlockToken: JsonToken;
        BlockObject: JsonObject;
        TypeToken: JsonToken;
        TextToken: JsonToken;
    begin
        if not Response.Get('content', ContentToken) then
            exit('');
        if not ContentToken.IsArray() then
            exit('');
        foreach BlockToken in ContentToken.AsArray() do begin
            BlockObject := BlockToken.AsObject();
            if BlockObject.Get('type', TypeToken) then
                if TypeToken.AsValue().AsText() = 'text' then
                    if BlockObject.Get('text', TextToken) then
                        ResultText += TextToken.AsValue().AsText();
        end;
    end;

    local procedure GetErrorDetail(ResponseText: Text): Text
    var
        ErrorObject: JsonObject;
        ErrorToken: JsonToken;
        MessageToken: JsonToken;
    begin
        if ErrorObject.ReadFrom(ResponseText) then
            if ErrorObject.Get('error', ErrorToken) then
                if ErrorToken.AsObject().Get('message', MessageToken) then
                    exit(MessageToken.AsValue().AsText());
        exit(CopyStr(ResponseText, 1, 1000));
    end;

    local procedure GetText(Source: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if Source.Get(PropertyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsText());
    end;

    local procedure GetBool(Source: JsonObject; PropertyName: Text): Boolean
    var
        Token: JsonToken;
    begin
        if Source.Get(PropertyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsBoolean());
    end;

    /// <summary>
    /// After trimming, the array may start with an orphaned assistant or tool_result
    /// message whose matching counterpart was removed. Strip those leading messages
    /// but always keep at least the last 2 (the current tool_use/tool_result pair).
    /// If the array still starts with an assistant message, prepend a synthetic user
    /// message to satisfy Anthropic's "first message must be role=user" constraint.
    /// </summary>
    local procedure RemoveOrphanedToolMessages(var Messages: JsonArray)
    var
        NewMessages: JsonArray;
        Token: JsonToken;
        MsgObj: JsonObject;
        ContentToken: JsonToken;
        FirstBlock: JsonToken;
        SyntheticUser: JsonObject;
        Role: Text;
        i: Integer;
    begin
        // Never remove the last 2 messages — they are the current tool_use/tool_result pair
        while Messages.Count() > 2 do begin
            Messages.Get(0, Token);
            if not Token.IsObject() then begin
                Messages.RemoveAt(0);
                continue;
            end;
            MsgObj := Token.AsObject();
            Role := GetText(MsgObj, 'role');

            if Role = 'assistant' then begin
                Messages.RemoveAt(0);
                continue;
            end;

            if Role <> 'user' then
                break;
            if not MsgObj.Get('content', ContentToken) then
                break;
            if not ContentToken.IsArray() then
                break;
            if ContentToken.AsArray().Count() = 0 then
                break;
            ContentToken.AsArray().Get(0, FirstBlock);
            if not FirstBlock.IsObject() then
                break;
            if GetText(FirstBlock.AsObject(), 'type') = 'tool_result' then begin
                Messages.RemoveAt(0);
                continue;
            end;
            break;
        end;

        if Messages.Count() = 0 then
            exit;

        Messages.Get(0, Token);
        if not Token.IsObject() then
            exit;
        if GetText(Token.AsObject(), 'role') = 'user' then
            exit;

        // First message is assistant — prepend a synthetic user message
        SyntheticUser.Add('role', 'user');
        SyntheticUser.Add('content', 'Continue.');
        NewMessages.Add(SyntheticUser);
        for i := 0 to Messages.Count() - 1 do begin
            Messages.Get(i, Token);
            NewMessages.Add(Token);
        end;
        Messages := NewMessages;
    end;

    local procedure LogApiCall(Operation: Text[50]; HttpMethod: Text[10]; RequestUrl: Text; HttpStatus: Integer; Elapsed: Duration; RequestText: Text; ResponseText: Text)
    var
        Setup: Record "Setup ori";
        Logger: Codeunit "Request Logger ori";
    begin
        Setup.SetLoadFields("Request Debug Mode");
        if not Setup.Get() then
            exit;
        if not Setup."Request Debug Mode" then
            exit;

        Logger.Log(Operation, HttpMethod, RequestUrl, ServiceNameTok,
            HttpStatus, Elapsed, true, '',
            RequestText, ResponseText,
            Enum::"Request Log Type ori"::"LLM");
        Logger.Insert();
    end;
}
