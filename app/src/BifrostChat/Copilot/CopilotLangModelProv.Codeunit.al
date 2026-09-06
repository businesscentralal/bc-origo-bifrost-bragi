namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

using System.AI;

/// <summary>
/// Implements the Bifrost Language Model Provider interface for the BC Copilot provider.
/// Uses System.AI managed resources — no API keys, no external endpoints.
/// </summary>
codeunit 10035385 "Copilot LangModel Prov. ori" implements "Bifrost LangModel Provider ori"
{
    Access = Internal;

    var
        CopilotNotEnabledLbl: Label 'Copilot is not enabled for Bifrost Chat. Ask your administrator to enable it in Copilot & AI Capabilities.', Comment = 'is-IS=Copilot er ekki virkjað fyrir Bifröst Chat. Biddu kerfisstjóra um að virkja það í Copilot og gervigreind.';
        FilesNotSupportedErr: Label 'The Copilot provider does not support file attachments. Use an external provider (OpenAI, Azure OpenAI, Anthropic) for document processing.', Comment = 'is-IS=Copilot veitandi styður ekki skráarviðhengi. Notaðu ytri veitanda (OpenAI, Azure OpenAI, Anthropic) til að vinna úr skjölum.';

    procedure Execute(var Argument: Record "Bifrost Chat Argument ori" temporary)
    var
        ProcType: Enum "Bifrost Chat Proc. Type ori";
    begin
        ProcType := Argument."Procedure Type";
        case ProcType of
            ProcType::IsConfigured:
                Argument."Result Boolean" := CheckIsConfigured();
            ProcType::BuildConfigJson:
                Argument.SetResultText(BuildConfigJsonInternal());
            ProcType::SendChatMessage:
                DoSendChatMessage(Argument);
            ProcType::CompletePrompt:
                DoCompletePrompt(Argument);
            ProcType::ContinueWithToolResults:
                Argument.SetResultText(BuildErrorJson('Copilot provider does not support split tool execution.'));
            ProcType::GetAvailableModels:
                Argument."Result Boolean" := false;
            ProcType::TestConnection:
                DoTestConnection(Argument);
            ProcType::GetTokenUsage:
                begin
                    Argument."Input Tokens" := 0;
                    Argument."Output Tokens" := 0;
                end;
            ProcType::GetProviderName:
                Argument.SetResultText('Copilot');
            ProcType::RequiresApiKey,
            ProcType::HasServiceKeyPermission,
            ProcType::SupportsSplitToolExecution,
            ProcType::SupportsModelSelection,
            ProcType::HasExternalEndpoint:
                Argument."Result Boolean" := false;
            ProcType::SupportsToolCalling:
                Argument."Result Boolean" := true;
            ProcType::GetMaxToolCount:
                Argument."Result Integer" := 20;
            ProcType::GetApiKeyLabel,
            ProcType::GetApiKeyInstruction,
            ProcType::GetApiKeyPlaceholder,
            ProcType::GetApiKeyDocsUrl,
            ProcType::GetApiKeyDocsLinkText,
            ProcType::GetServiceKeyDescription,
            ProcType::GetDefaultBaseUrl,
            ProcType::GetDefaultModel,
            ProcType::GetDefaultSkillUrl:
                Argument.SetResultText('');
            ProcType::GetDefaultSkillText:
                Argument.SetResultText(GetDefaultSkillTextInternal());
            ProcType::GetDefaultTimeoutSeconds,
            ProcType::GetDefaultMaxTokens,
            ProcType::GetContextWindowChars:
                Argument."Result Integer" := 0;
        end;
    end;

    local procedure CheckIsConfigured(): Boolean
    var
        CopilotCapability: Codeunit "Copilot Capability";
    begin
        if not CopilotCapability.IsCapabilityRegistered(Enum::"Copilot Capability"::"Bifrost Chat ori") then
            exit(false);
        exit(CopilotCapability.IsCapabilityActive(Enum::"Copilot Capability"::"Bifrost Chat ori"));
    end;

    local procedure BuildConfigJsonInternal(): Text
    var
        Config: JsonObject;
        Labels: JsonObject;
        ConfigText: Text;
        ThinkingLbl: Label 'Thinking...', Comment = 'is-IS=Hugsar...';
        WaitingLbl: Label 'Waiting for response...', Comment = 'is-IS=Bíð eftir svari...';
        InputPlaceholderLbl: Label 'Ask about your Business Central data...', Comment = 'is-IS=Spurðu um Business Central gögnin þín...';
        SendBtnLbl: Label 'Send', Comment = 'is-IS=Senda';
        ReadyToChatLbl: Label 'Ready to chat.', Comment = 'is-IS=Tilbúið til spjalls.';
        ConnectedLbl: Label 'Connected', Comment = 'is-IS=Tengt';
        ValidatingLbl: Label 'Validating connection...', Comment = 'is-IS=Staðfesti tengingu...';
        ToolErrorsLbl: Label 'Tool errors', Comment = 'is-IS=Verkfæravillur';
        FailedParseLbl: Label 'Failed to parse response.', Comment = 'is-IS=Ekki tókst að þátta svar.';
        InvalidFormatLbl: Label 'Invalid response format.', Comment = 'is-IS=Ógilt svarsnið.';
        FailedHistoryLbl: Label 'Failed to restore chat history.', Comment = 'is-IS=Ekki tókst að endurheimta spjallsögu.';
        SavePersonalKeyLbl: Label 'Save Personal Key', Comment = 'is-IS=Vista persónulegan lykil';
        SaveServiceKeyLbl: Label 'Save as Shared Key', Comment = 'is-IS=Vista sem sameiginlegan lykil';
        PersonalKeySavedLbl: Label 'Personal key saved. You can now chat.', Comment = 'is-IS=Persónulegur lykill vistaður. Nú getur þú spjallað.';
        ServiceKeySavedLbl: Label 'Shared key saved for all users in this company.', Comment = 'is-IS=Sameiginlegur lykill vistaður fyrir alla notendur í þessu fyrirtæki.';
        ServiceKeyExistsLbl: Label 'A shared key is configured. Enter a personal key to override it, or leave empty to use the shared key.', Comment = 'is-IS=Sameiginlegur lykill er stilltur. Sláðu inn persónulegan lykil til að hnekkja honum, eða skildu eftir autt til að nota sameiginlega lykilinn.';
        ChatDisabledLbl: Label 'Bifrost Chat is disabled. Assign a Language Model with a provider in your Bifrost User Setup to enable chat.', Comment = 'is-IS=Spjalla við Bifröst er óvirkt. Úthlutaðu mállíkani með veitanda í Bifröst notandauppsetningu til að virkja spjall.';
        ApiKeyLabelLbl: Label 'API Key', Comment = 'is-IS=API-lykill';
        ApiKeyInstructionLbl: Label 'Enter your key to enable chat.', Comment = 'is-IS=Sláðu inn lykilinn þinn til að virkja spjall.';
        DefaultSkillInstructionTok: Label 'On startup, call the who_am_i tool to learn about the current user and company.', Locked = true;
    begin
        Labels.Add('thinking', ThinkingLbl);
        Labels.Add('waitingForResponse', WaitingLbl);
        Labels.Add('inputPlaceholder', InputPlaceholderLbl);
        Labels.Add('sendBtn', SendBtnLbl);
        Labels.Add('readyToChat', ReadyToChatLbl);
        Labels.Add('connected', ConnectedLbl);
        Labels.Add('validatingConnection', ValidatingLbl);
        Labels.Add('toolErrors', ToolErrorsLbl);
        Labels.Add('failedToParseResponse', FailedParseLbl);
        Labels.Add('invalidResponseFormat', InvalidFormatLbl);
        Labels.Add('failedRestoreHistory', FailedHistoryLbl);
        Labels.Add('savePersonalKey', SavePersonalKeyLbl);
        Labels.Add('saveServiceKey', SaveServiceKeyLbl);
        Labels.Add('apiKeySaved', PersonalKeySavedLbl);
        Labels.Add('serviceKeySaved', ServiceKeySavedLbl);
        Labels.Add('serviceKeyExists', ServiceKeyExistsLbl);
        Labels.Add('chatDisabled', ChatDisabledLbl);
        Labels.Add('apiKeyLabel', ApiKeyLabelLbl);
        Labels.Add('apiKeyInstruction', ApiKeyInstructionLbl);

        Config.Add('provider', 'Copilot');
        Config.Add('authMode', 'none');
        Config.Add('requiresApiKey', false);
        Config.Add('labels', Labels);
        Config.Add('defaultSkillInstruction', DefaultSkillInstructionTok);

        Config.WriteTo(ConfigText);
        exit(ConfigText);
    end;

    [NonDebuggable]
    local procedure DoSendChatMessage(var Argument: Record "Bifrost Chat Argument ori" temporary)
    var
        CopilotProxy: Codeunit "Copilot Chat Proxy ori";
    begin
        if not CheckIsConfigured() then begin
            Argument.SetResultText(BuildErrorJson(CopilotNotEnabledLbl));
            exit;
        end;
        Argument.SetResultText(CopilotProxy.SendChatMessage(Argument.GetPayload()));
    end;

    [NonDebuggable]
    local procedure DoCompletePrompt(var Argument: Record "Bifrost Chat Argument ori" temporary)
    var
        AzureOpenAI: Codeunit "Azure OpenAI";
        AOAIDeployments: Codeunit "AOAI Deployments";
        AOAIChatMessages: Codeunit "AOAI Chat Messages";
        AOAIChatCompletionParams: Codeunit "AOAI Chat Completion Params";
        AOAIOperationResponse: Codeunit "AOAI Operation Response";
        PayloadObject: JsonObject;
        SystemPrompt: Text;
        UserPrompt: Text;
        ResponseObj: JsonObject;
        ResultText: Text;
    begin
        if not CheckIsConfigured() then begin
            Argument.SetResultText(BuildErrorJson(CopilotNotEnabledLbl));
            exit;
        end;

        if not PayloadObject.ReadFrom(Argument.GetPayload()) then begin
            Argument.SetResultText(BuildErrorJson('Invalid payload JSON.'));
            exit;
        end;

        AzureOpenAI.SetCopilotCapability(Enum::"Copilot Capability"::"Bifrost Chat ori");
        AzureOpenAI.SetManagedResourceAuthorization(Enum::"AOAI Model Type"::"Chat Completions", AOAIDeployments.GetGPT41Latest());

        SystemPrompt := GetPayloadText(PayloadObject, 'systemPrompt');
        if SystemPrompt <> '' then
            AOAIChatMessages.SetPrimarySystemMessage(SystemPrompt);

        UserPrompt := GetFirstUserMessage(PayloadObject);
        if HasFiles(PayloadObject) then begin
            Argument.SetResultText(BuildErrorJson(FilesNotSupportedErr));
            exit;
        end;
        AOAIChatMessages.AddUserMessage(UserPrompt);
        AOAIChatCompletionParams.SetMaxTokens(4096);

        AzureOpenAI.GenerateChatCompletion(AOAIChatMessages, AOAIChatCompletionParams, AOAIOperationResponse);

        if not AOAIOperationResponse.IsSuccess() then begin
            Argument.SetResultText(BuildErrorJson(GetErrorOrFallback(AOAIOperationResponse)));
            exit;
        end;

        ResponseObj.Add('reply', AOAIChatMessages.GetLastMessage());
        ResponseObj.WriteTo(ResultText);
        Argument.SetResultText(ResultText);
    end;

    local procedure GetPayloadText(PayloadObject: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if PayloadObject.Get(PropertyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsText());
    end;

    local procedure GetFirstUserMessage(PayloadObject: JsonObject): Text
    var
        MessagesToken: JsonToken;
        MessageToken: JsonToken;
        MessageObject: JsonObject;
    begin
        if not PayloadObject.Get('messages', MessagesToken) then
            exit('');
        if not MessagesToken.IsArray() then
            exit('');
        foreach MessageToken in MessagesToken.AsArray() do begin
            MessageObject := MessageToken.AsObject();
            if GetPayloadText(MessageObject, 'role') = 'user' then
                exit(GetPayloadText(MessageObject, 'content'));
        end;
    end;

    local procedure HasFiles(PayloadObject: JsonObject): Boolean
    var
        FilesToken: JsonToken;
    begin
        if not PayloadObject.Get('files', FilesToken) then
            exit(false);
        exit(FilesToken.IsArray() and (FilesToken.AsArray().Count() > 0));
    end;

    local procedure GetErrorOrFallback(var AOAIOperationResponse: Codeunit "AOAI Operation Response"): Text
    var
        ErrorText: Text;
        FallbackErr: Label 'The Copilot model returned an error.', Comment = 'is-IS=Copilot líkanið skilaði villu.';
    begin
        ErrorText := AOAIOperationResponse.GetError();
        if ErrorText = '' then
            exit(FallbackErr);
        exit(ErrorText);
    end;

    local procedure DoTestConnection(var Argument: Record "Bifrost Chat Argument ori" temporary)
    var
        CopilotCapability: Codeunit "Copilot Capability";
        NotRegisteredErr: Label 'The Bifrost Chat capability is not registered. Try reinstalling the extension.', Comment = 'is-IS=Bifröst Chat hæfnin er ekki skráð. Prófaðu að setja viðbótina upp aftur.';
    begin
        if not CopilotCapability.IsCapabilityRegistered(Enum::"Copilot Capability"::"Bifrost Chat ori") then begin
            Argument.SetErrorMessage(NotRegisteredErr);
            Argument."Result Boolean" := false;
            exit;
        end;

        if not CopilotCapability.IsCapabilityActive(Enum::"Copilot Capability"::"Bifrost Chat ori") then begin
            Argument.SetErrorMessage(CopilotNotEnabledLbl);
            Argument."Result Boolean" := false;
            exit;
        end;

        Argument."Result Boolean" := true;
    end;

    local procedure GetDefaultSkillTextInternal(): Text
    var
        DefaultSkill: Codeunit "Copilot Default Skill ori";
    begin
        exit(DefaultSkill.GetSkillText());
    end;

    local procedure BuildErrorJson(ErrorMessage: Text): Text
    var
        ErrorObj: JsonObject;
        Result: Text;
    begin
        ErrorObj.Add('error', ErrorMessage);
        ErrorObj.WriteTo(Result);
        exit(Result);
    end;
}
