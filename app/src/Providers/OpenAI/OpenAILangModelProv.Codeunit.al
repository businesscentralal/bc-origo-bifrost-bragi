namespace Origo.Bifrost.Bragi;
using Microsoft.Utilities;
using Origo.Bifrost;

/// <summary>
/// OpenAI provider implementation using Bearer token authentication.
/// </summary>
codeunit 10035413 "OpenAI LangModel Prov. ori" implements "Bifrost LangModel Provider ori"
{
    Access = Internal;

    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        AuthHeaderNameTok: Label 'Authorization', Locked = true;
        ProviderNameTok: Label 'OpenAI', Locked = true;
        ApiKeyLabelLbl: Label 'API Key', Comment = 'is-IS=API-lykill';
        ApiKeyInstructionLbl: Label 'Enter your OpenAI API key.', Comment = 'is-IS=Sláðu inn OpenAI API-lykilinn þinn.';
        ApiKeyPlaceholderTok: Label 'sk-...', Locked = true;
        ApiKeyDocsUrlTok: Label 'https://platform.openai.com/api-keys', Locked = true;
        ApiKeyDocsLinkTextLbl: Label 'Get key from OpenAI Platform', Comment = 'is-IS=Sækja lykil á OpenAI Platform';
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
                Argument.SetResultText(ApiKeyPlaceholderTok);
            ProcType::GetApiKeyDocsUrl:
                Argument.SetResultText(ApiKeyDocsUrlTok);
            ProcType::GetApiKeyDocsLinkText:
                Argument.SetResultText(ApiKeyDocsLinkTextLbl);
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
                Argument."Result Integer" := 120;
            ProcType::GetDefaultMaxTokens:
                Argument."Result Integer" := 16384;
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
        ConfigJson.Add('timeoutMs', ProviderBase.GetTimeoutMs(Argument, 120000));
        ConfigJson.Add('maxTokens', ProviderBase.GetMaxTokens(Argument, 16384));
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
        RequestBody.Add('max_completion_tokens', ProviderBase.GetMaxTokens(Argument, 16384));
        RequestBody.Add('messages', Messages);

        ChatUrl := ProviderBase.GetBaseUrl(Argument, '') + '/v1/chat/completions';
        Response := ApiClient.SendToEndpoint(ChatUrl, AuthHeaderNameTok, Argument.GetApiKey(),
            ProviderBase.GetTimeoutMs(Argument, 120000), RequestBody);
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
        NoKeyErr: Label 'No API key configured. Enter a personal or shared API key.', Comment = 'is-IS=Enginn API-lykill stilltur. Sláðu inn persónulegan eða sameiginlegan API-lykil.';
        NoBaseUrlErr: Label 'No Base URL configured for this language model.', Comment = 'is-IS=Engin grunnslóð stillt fyrir þetta mállíkan.';
    begin
        if not Argument.HasApiKey() then begin
            Argument.SetErrorMessage(NoKeyErr);
            exit(false);
        end;
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
