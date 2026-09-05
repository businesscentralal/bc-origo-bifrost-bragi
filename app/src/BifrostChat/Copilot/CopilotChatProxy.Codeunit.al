namespace Origo.Bifrost.Bragi;
using Origo.Bifrost;

using System.AI;
using System.Text;

/// <summary>
/// Runs the Copilot agentic tool loop. Calls Azure OpenAI via System.AI,
/// dispatches tool calls via the Core MCP Tool Server, feeds results back,
/// and repeats until the model produces a final answer.
/// </summary>
codeunit 10035393 "Copilot Chat Proxy ori"
{
    Access = Internal;

    var
        ToolServer: Codeunit "MCP Tool Server ori";
        ChatUtils: Codeunit "Bifrost Chat Utils ori";
        RequestLogger: Codeunit "Request Logger ori";
        UnexpectedErrorLbl: Label 'An unexpected error occurred while calling the Copilot model.', Comment = 'is-IS=Óvænt villa kom upp við kall á Copilot líkanið.';
        MissingMessagesLbl: Label 'Payload must contain a messages array with at least one entry.', Comment = 'is-IS=Inntak verður að innihalda skilaboðalista með að minnsta kosti einu atriði.';

    [NonDebuggable]
    internal procedure SendChatMessage(PayloadJson: Text): Text
    var
        AzureOpenAI: Codeunit "Azure OpenAI";
        AOAIDeployments: Codeunit "AOAI Deployments";
        AOAIChatMessages: Codeunit "AOAI Chat Messages";
        AOAIChatCompletionParams: Codeunit "AOAI Chat Completion Params";
        AOAIOperationResponse: Codeunit "AOAI Operation Response";
        PayloadObject: JsonObject;
        ToolTrace: JsonArray;
        SystemPrompt: Text;
        Reply: Text;
        ResponseJson: Text;
        Iteration: Integer;
        MaxIterations: Integer;
        StartTime: DateTime;
    begin
        StartTime := CurrentDateTime();

        if not PayloadObject.ReadFrom(PayloadJson) then
            exit(BuildErrorResponse('Invalid payload JSON.'));

        if not HasMessages(PayloadObject) then
            exit(BuildErrorResponse(MissingMessagesLbl));

        AzureOpenAI.SetCopilotCapability(Enum::"Copilot Capability"::"Bifrost Chat ori");
        AzureOpenAI.SetManagedResourceAuthorization(Enum::"AOAI Model Type"::"Chat Completions", AOAIDeployments.GetGPT41Latest());

        SystemPrompt := BuildSystemPrompt(PayloadObject);
        AOAIChatMessages.SetPrimarySystemMessage(SystemPrompt);
        ParseMessages(PayloadObject, AOAIChatMessages);
        AddToolDefinitions(AOAIChatMessages);
        AOAIChatCompletionParams.SetMaxTokens(4096);

        MaxIterations := 25;
        for Iteration := 1 to MaxIterations do begin
            AzureOpenAI.GenerateChatCompletion(AOAIChatMessages, AOAIChatCompletionParams, AOAIOperationResponse);

            if not AOAIOperationResponse.IsSuccess() then begin
                ResponseJson := BuildErrorResponse(GetErrorOrFallback(AOAIOperationResponse));
                LogRequest('ChatCompletion', SystemPrompt, ResponseJson, false, GetErrorOrFallback(AOAIOperationResponse), StartTime);
                exit(ResponseJson);
            end;

            if not AOAIOperationResponse.IsFunctionCall() then begin
                Reply := AOAIChatMessages.GetLastMessage();
                ResponseJson := BuildSuccessResponse(Reply, ToolTrace);
                LogRequest('ChatCompletion', SystemPrompt, ResponseJson, true, '', StartTime);
                exit(ResponseJson);
            end;

            ExecuteToolCalls(AOAIOperationResponse, AOAIChatMessages, ToolTrace);
        end;

        Reply := AOAIChatMessages.GetLastMessage();
        ResponseJson := BuildSuccessResponse(Reply, ToolTrace);
        LogRequest('ChatCompletion', SystemPrompt, ResponseJson, true, '', StartTime);
        exit(ResponseJson);
    end;

    local procedure BuildSystemPrompt(PayloadObject: JsonObject) SystemPrompt: Text
    var
        PromptBuilder: TextBuilder;
        RecordContextToken: JsonToken;
        RecordContext: Text;
        UserPrompt: Text;
        UserSkill: Text;
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

        UserPrompt := GetTextProperty(PayloadObject, 'systemPrompt');
        if UserPrompt <> '' then begin
            PromptBuilder.AppendLine();
            PromptBuilder.AppendLine();
            PromptBuilder.AppendLine('USER INSTRUCTIONS:');
            PromptBuilder.Append(UserPrompt);
        end;

        UserSkill := GetTextProperty(PayloadObject, 'contextSkill');
        if UserSkill <> '' then begin
            PromptBuilder.AppendLine();
            PromptBuilder.AppendLine();
            PromptBuilder.AppendLine('SKILL REFERENCE:');
            PromptBuilder.Append(UserSkill);
        end;

        SystemPrompt := PromptBuilder.ToText();
    end;

    local procedure AddToolDefinitions(var AOAIChatMessages: Codeunit "AOAI Chat Messages")
    var
        ServerTools: JsonArray;
        ToolToken: JsonToken;
        ToolObject: JsonObject;
        SchemaToken: JsonToken;
        EmptySchema: JsonObject;
        ToolName: Text;
        ToolDescription: Text;
        ToolCount: Integer;
    begin
        ToolCount := 0;
        AOAIChatMessages.SetToolInvokePreference(Enum::"AOAI Tool Invoke Preference"::Manual);
        ToolServer.ListTools(ServerTools);
        foreach ToolToken in ServerTools do begin
            if ToolCount >= MaxToolsPerRequest() then
                break;
            ToolObject := ToolToken.AsObject();
            ToolName := GetTextProperty(ToolObject, 'name');
            ToolDescription := GetTextProperty(ToolObject, 'description');

            Clear(EmptySchema);
            if ToolObject.Get('inputSchema', SchemaToken) then
                if SchemaToken.IsObject() then
                    EmptySchema := SchemaToken.AsObject();

            RegisterTool(AOAIChatMessages, ToolName, ToolDescription, EmptySchema);
            ToolCount += 1;
        end;
    end;

    local procedure RegisterTool(var AOAIChatMessages: Codeunit "AOAI Chat Messages"; ToolName: Text; ToolDescription: Text; Schema: JsonObject)
    var
        ToolImpl: Codeunit "Copilot AOAI Func Impl ori";
    begin
        ToolImpl.SetToolData(ToolName, ToolDescription, Schema);
        AOAIChatMessages.AddTool(ToolImpl);
    end;

    local procedure ExecuteToolCalls(var AOAIOperationResponse: Codeunit "AOAI Operation Response"; var AOAIChatMessages: Codeunit "AOAI Chat Messages"; var ToolTrace: JsonArray)
    var
        AOAIFunctionResponse: Codeunit "AOAI Function Response";
        FunctionName: Text;
        Arguments: JsonObject;
        ArgumentsText: Text;
        ToolCallId: Text;
        ToolResult: Text;
        IsError: Boolean;
        TraceEntry: JsonObject;
    begin
        foreach AOAIFunctionResponse in AOAIOperationResponse.GetFunctionResponses() do begin
            FunctionName := AOAIFunctionResponse.GetFunctionName();
            Arguments := AOAIFunctionResponse.GetArguments();
            ToolCallId := AOAIFunctionResponse.GetFunctionId();

            ToolServer.CallTool(FunctionName, Arguments, ToolResult, IsError);
            ToolResult := ChatUtils.TruncateContent(ToolResult, 0);
            AOAIChatMessages.AddToolMessage(ToolCallId, FunctionName, ToolResult);

            Arguments.WriteTo(ArgumentsText);
            Clear(TraceEntry);
            TraceEntry.Add('tool', FunctionName);
            TraceEntry.Add('input', ArgumentsText);
            TraceEntry.Add('output', ShortenForTrace(ToolResult));
            ToolTrace.Add(TraceEntry);
        end;
    end;

    local procedure ParseMessages(PayloadObject: JsonObject; var AOAIChatMessages: Codeunit "AOAI Chat Messages")
    var
        MessagesToken: JsonToken;
        MessageToken: JsonToken;
        MessageObject: JsonObject;
        Role: Text;
        Content: Text;
    begin
        if not PayloadObject.Get('messages', MessagesToken) then
            exit;
        if not MessagesToken.IsArray() then
            exit;

        foreach MessageToken in MessagesToken.AsArray() do begin
            MessageObject := MessageToken.AsObject();
            Role := GetTextProperty(MessageObject, 'role');
            Content := GetTextProperty(MessageObject, 'content');
            case Role of
                'user':
                    AOAIChatMessages.AddUserMessage(Content);
                'assistant':
                    AOAIChatMessages.AddAssistantMessage(Content);
            end;
        end;
    end;

    local procedure BuildSuccessResponse(Reply: Text; ToolTrace: JsonArray): Text
    var
        Response: JsonObject;
    begin
        Response.Add('type', 'reply');
        Response.Add('reply', Reply);
        if ToolTrace.Count() > 0 then
            Response.Add('toolTrace', ToolTrace);
        exit(JsonToText(Response));
    end;

    local procedure BuildErrorResponse(ErrorMessage: Text): Text
    var
        Response: JsonObject;
    begin
        Response.Add('error', ErrorMessage);
        exit(JsonToText(Response));
    end;

    local procedure LogRequest(Operation: Text[50]; RequestBody: Text; ResponseBody: Text; IsSuccess: Boolean; ErrorText: Text; StartTime: DateTime)
    var
        Setup: Record "Setup ori";
    begin
        Setup.SetLoadFields("Request Debug Mode");
        if not Setup.Get() then
            exit;
        if not Setup."Request Debug Mode" then
            exit;

        RequestLogger.Log(
            Operation,
            'POST',
            'copilot://managed/chat-completions',
            'Copilot',
            200,
            CurrentDateTime() - StartTime,
            IsSuccess,
            ErrorText,
            RequestBody,
            ResponseBody,
            Enum::"Request Log Type ori"::"Copilot");
        RequestLogger.Insert();
    end;

    local procedure MaxToolsPerRequest(): Integer
    begin
        exit(20);
    end;

    local procedure GetErrorOrFallback(var AOAIOperationResponse: Codeunit "AOAI Operation Response"): Text
    var
        ErrorText: Text;
    begin
        ErrorText := AOAIOperationResponse.GetError();
        if ErrorText = '' then begin
            ErrorText := GetLastErrorText();
            if ErrorText = '' then
                exit(UnexpectedErrorLbl);
        end;
        exit(ErrorText);
    end;

    local procedure GetTextProperty(Source: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if Source.Get(PropertyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure ShortenForTrace(Value: Text): Text
    begin
        if StrLen(Value) <= 500 then
            exit(Value);
        exit(CopyStr(Value, 1, 497) + '...');
    end;

    local procedure JsonToText(Source: JsonObject): Text
    var
        Result: Text;
    begin
        Source.WriteTo(Result);
        exit(Result);
    end;

    local procedure HasMessages(PayloadObject: JsonObject): Boolean
    var
        MessagesToken: JsonToken;
    begin
        if not PayloadObject.Get('messages', MessagesToken) then
            exit(false);
        if not MessagesToken.IsArray() then
            exit(false);
        exit(MessagesToken.AsArray().Count() > 0);
    end;
}
