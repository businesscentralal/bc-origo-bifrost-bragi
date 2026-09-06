namespace Origo.Bifrost.Bragi;
using Microsoft.Utilities;
using Origo.Bifrost;

/// <summary>
/// Custom/self-hosted LLM provider implementation using x-api-key header authentication.
/// Suitable for Ollama, vLLM, and other OpenAI-compatible endpoints.
/// </summary>
codeunit 10035415 "Custom LLM LangModel Prov. ori" implements "Bifrost LangModel Provider ori"
{
    Access = Internal;

    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        AuthHeaderNameTok: Label 'x-api-key', Locked = true;
        ProviderNameTok: Label 'Custom LLM', Locked = true;
        ApiKeyLabelLbl: Label 'API Key', Comment = 'is-IS=API-lykill';
        ApiKeyInstructionLbl: Label 'Enter the API key for your LLM endpoint.', Comment = 'is-IS=Sláðu inn API-lykilinn fyrir LLM endapunktinn þinn.';
        ServiceKeyDescLbl: Label 'Shared keys are used by all users in this company who do not have a personal key.', Comment = 'is-IS=Sameiginlegir lyklar eru notaðir af öllum notendum í þessu fyrirtæki sem hafa ekki persónulegan lykil.';

    procedure Execute(var Argument: Record "Bifrost Chat Argument ori" temporary)
    var
        ProcType: Enum "Bifrost Chat Proc. Type ori";
    begin
        ProcType := Argument."Procedure Type";
        case ProcType of
            ProcType::IsConfigured:
                Argument."Result Boolean" := CheckIsConfigured(Argument);
            ProcType::BuildConfigJson:
                Argument.SetResultText(DoBuildConfigJson(Argument));
            ProcType::SendChatMessage:
                Argument.SetResultText(DoSendChatMessage(Argument));
            ProcType::CompletePrompt:
                Argument.SetResultText(DoCompletePrompt(Argument));
            ProcType::ContinueWithToolResults:
                Argument.SetResultText(DoContinueWithToolResults(Argument));
            ProcType::GetAvailableModels:
                Argument."Result Boolean" := DoGetAvailableModels(Argument);
            ProcType::TestConnection:
                Argument."Result Boolean" := DoTestConnection(Argument);
            ProcType::GetTokenUsage:
                DoGetTokenUsage(Argument);
            ProcType::GetProviderName:
                Argument.SetResultText(ProviderNameTok);
            ProcType::RequiresApiKey:
                Argument."Result Boolean" := true;
            ProcType::GetApiKeyLabel:
                Argument.SetResultText(ApiKeyLabelLbl);
            ProcType::GetApiKeyInstruction:
                Argument.SetResultText(ApiKeyInstructionLbl);
            ProcType::GetApiKeyPlaceholder:
                Argument.SetResultText('');
            ProcType::GetApiKeyDocsUrl:
                Argument.SetResultText('');
            ProcType::GetApiKeyDocsLinkText:
                Argument.SetResultText('');
            ProcType::GetServiceKeyDescription:
                Argument.SetResultText(ServiceKeyDescLbl);
            ProcType::HasServiceKeyPermission:
                Argument."Result Boolean" := ProviderBase.HasServiceKeyPermission();
            ProcType::GetMaxToolCount:
                Argument."Result Integer" := 0;
            ProcType::SupportsSplitToolExecution:
                Argument."Result Boolean" := true;
            ProcType::SupportsModelSelection:
                Argument."Result Boolean" := true;
            ProcType::SupportsToolCalling:
                Argument."Result Boolean" := true;
            ProcType::HasExternalEndpoint:
                Argument."Result Boolean" := true;
            ProcType::GetDefaultBaseUrl:
                Argument.SetResultText('');
            ProcType::GetDefaultModel:
                Argument.SetResultText('');
            ProcType::GetDefaultTimeoutSeconds:
                Argument."Result Integer" := 300;
            ProcType::GetDefaultMaxTokens:
                Argument."Result Integer" := 8192;
            ProcType::GetContextWindowChars:
                Argument."Result Integer" := 80000;
            ProcType::GetDefaultSkillUrl:
                Argument.SetResultText('');
            ProcType::GetDefaultSkillText:
                Argument.SetResultText('');
        end;
    end;

    local procedure CheckIsConfigured(var Argument: Record "Bifrost Chat Argument ori" temporary): Boolean
    begin
        exit(ProviderBase.IsConfigured(Argument, ''));
    end;

    [NonDebuggable]
    local procedure DoBuildConfigJson(var Argument: Record "Bifrost Chat Argument ori" temporary): Text
    var
        ConfigJson: JsonObject;
        ConfigText: Text;
    begin
        ProviderBase.EnsureHttpClientAllowed();
        ConfigJson.Add('provider', ProviderNameTok);
        ConfigJson.Add('apiKey', Argument.GetApiKeyIndicator());
        ConfigJson.Add('model', ProviderBase.GetModel(Argument, ''));
        ConfigJson.Add('baseUrl', ProviderBase.GetBaseUrl(Argument, ''));
        ConfigJson.Add('timeoutMs', ProviderBase.GetTimeoutMs(Argument, 300000));
        ConfigJson.Add('maxTokens', ProviderBase.GetMaxTokens(Argument, 8192));
        ConfigJson.WriteTo(ConfigText);
        exit(ConfigText);
    end;

    local procedure DoSendChatMessage(var Argument: Record "Bifrost Chat Argument ori" temporary): Text
    var
        LangModelChatProxy: Codeunit "LangModel Chat Proxy ori";
    begin
        exit(LangModelChatProxy.SendChatMessage(Argument, Argument.GetPayload(), AuthHeaderNameTok));
    end;

    [NonDebuggable]
    local procedure DoCompletePrompt(var Argument: Record "Bifrost Chat Argument ori" temporary): Text
    var
        ApiClient: Codeunit "LangModel API Client ori";
        RequestBody: JsonObject;
        PayloadObject: JsonObject;
        Messages: JsonArray;
        SystemMsg: JsonObject;
        Response: JsonObject;
        ResponseObj: JsonObject;
        SystemPrompt: Text;
        ChatUrl: Text;
        ResultText: Text;
    begin
        ProviderBase.EnsureHttpClientAllowed();
        if not PayloadObject.ReadFrom(Argument.GetPayload()) then
            exit(BuildErrorJson('Invalid payload JSON.'));

        SystemPrompt := GetJsonText(PayloadObject, 'systemPrompt');
        if SystemPrompt <> '' then begin
            SystemMsg.Add('role', 'system');
            SystemMsg.Add('content', SystemPrompt);
            Messages.Add(SystemMsg);
        end;
        AppendPayloadMessages(PayloadObject, Messages);
        ProviderBase.AttachFilesToMessages(PayloadObject, Messages);

        RequestBody.Add('model', ProviderBase.GetModel(Argument, ''));
        RequestBody.Add('max_completion_tokens', ProviderBase.GetMaxTokens(Argument, 8192));
        RequestBody.Add('messages', Messages);

        ChatUrl := ProviderBase.GetBaseUrl(Argument, '') + '/v1/chat/completions';
        Response := ApiClient.SendToEndpoint(ChatUrl, AuthHeaderNameTok, Argument.GetApiKey(),
            ProviderBase.GetTimeoutMs(Argument, 300000), RequestBody);
        ApiClient.LogLastRequest();

        ResponseObj.Add('reply', ApiClient.ExtractText(Response));
        ResponseObj.WriteTo(ResultText);
        exit(ResultText);
    end;

    local procedure AppendPayloadMessages(PayloadObject: JsonObject; var Messages: JsonArray)
    var
        MessagesToken: JsonToken;
        MessageToken: JsonToken;
    begin
        if not PayloadObject.Get('messages', MessagesToken) then
            exit;
        if not MessagesToken.IsArray() then
            exit;
        foreach MessageToken in MessagesToken.AsArray() do
            Messages.Add(MessageToken);
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

    local procedure DoContinueWithToolResults(var Argument: Record "Bifrost Chat Argument ori" temporary): Text
    var
        LangModelChatProxy: Codeunit "LangModel Chat Proxy ori";
    begin
        exit(LangModelChatProxy.ContinueWithToolResults(Argument, Argument.GetConversationState(), Argument.GetToolResults(), AuthHeaderNameTok));
    end;

    local procedure DoGetAvailableModels(var Argument: Record "Bifrost Chat Argument ori" temporary): Boolean
    var
        TempNameValueBuffer: Record "Name/Value Buffer" temporary;
        ApiClient: Codeunit "LangModel API Client ori";
        ModelsArray: JsonArray;
        ModelToken: JsonToken;
        ModelObject: JsonObject;
        BaseUrl: Text;
        IdValue: Text;
        EntryNo: Integer;
    begin
        BaseUrl := ProviderBase.GetBaseUrl(Argument, '');
        if BaseUrl = '' then
            exit(false);

        ModelsArray := ApiClient.ListModelsFromEndpoint(BaseUrl + '/v1/models', AuthHeaderNameTok, Argument.GetApiKey());

        foreach ModelToken in ModelsArray do begin
            ModelObject := ModelToken.AsObject();
            IdValue := GetJsonText(ModelObject, 'id');
            if IdValue <> '' then begin
                EntryNo += 1;
                TempNameValueBuffer.Init();
                TempNameValueBuffer.ID := EntryNo;
                TempNameValueBuffer.Name := CopyStr(IdValue, 1, MaxStrLen(TempNameValueBuffer.Name));
                TempNameValueBuffer.Value := CopyStr(IdValue, 1, MaxStrLen(TempNameValueBuffer.Value));
                TempNameValueBuffer.Insert();
            end;
        end;
        Argument.SetModels(TempNameValueBuffer);
        exit(EntryNo > 0);
    end;

    local procedure DoTestConnection(var Argument: Record "Bifrost Chat Argument ori" temporary): Boolean
    var
        ApiClient: Codeunit "LangModel API Client ori";
        BaseUrl: Text;
        NoBaseUrlErr: Label 'No Base URL configured for this language model.', Comment = 'is-IS=Engin grunnslóð stillt fyrir þetta mállíkan.';
    begin
        BaseUrl := ProviderBase.GetBaseUrl(Argument, '');
        if BaseUrl = '' then begin
            Argument.SetErrorMessage(NoBaseUrlErr);
            exit(false);
        end;
        ApiClient.ListModelsFromEndpoint(BaseUrl + '/v1/models', AuthHeaderNameTok, Argument.GetApiKey());
        exit(true);
    end;

    local procedure DoGetTokenUsage(var Argument: Record "Bifrost Chat Argument ori" temporary)
    var
        InTokens: Integer;
        OutTokens: Integer;
    begin
        ProviderBase.ParseTokenUsage(Argument.GetPayload(), InTokens, OutTokens);
        Argument."Input Tokens" := InTokens;
        Argument."Output Tokens" := OutTokens;
    end;

    local procedure GetJsonText(JObject: JsonObject; PropertyName: Text): Text
    var
        JToken: JsonToken;
    begin
        if JObject.Get(PropertyName, JToken) then
            if JToken.IsValue() then
                exit(JToken.AsValue().AsText());
    end;
}
