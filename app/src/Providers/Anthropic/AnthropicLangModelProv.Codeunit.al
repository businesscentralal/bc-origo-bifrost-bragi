namespace Origo.Bifrost.LanguageModels;
using Microsoft.Utilities;
using Origo.Bifrost;

/// <summary>
/// Anthropic (Claude) provider implementation using x-api-key + anthropic-version headers.
/// Delegates chat to the Anthropic-specific proxy since the Messages API differs from OpenAI.
/// </summary>
codeunit 10035416 "Anthropic LangModel Prov. ori" implements "Bifrost LangModel Provider ori"
{
    Access = Internal;

    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        DefaultBaseUrlTok: Label 'https://api.anthropic.com', Locked = true;
        DefaultModelTok: Label 'claude-sonnet-4-6', Locked = true;
        ProviderNameTok: Label 'Anthropic', Locked = true;
        ApiKeyLabelLbl: Label 'API Key', Comment = 'is-IS=API-lykill';
        ApiKeyInstructionLbl: Label 'Enter your Anthropic API key.', Comment = 'is-IS=Sláðu inn Anthropic API-lykilinn þinn.';
        ApiKeyPlaceholderTok: Label 'sk-ant-...', Locked = true;
        ApiKeyDocsUrlTok: Label 'https://console.anthropic.com/settings/keys', Locked = true;
        ApiKeyDocsLinkTextLbl: Label 'Get key from Anthropic Console', Comment = 'is-IS=Sækja lykil á Anthropic Console';
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
                Argument.SetResultText(DefaultBaseUrlTok);
            ProcType::GetDefaultModel:
                Argument.SetResultText(DefaultModelTok);
            ProcType::GetDefaultTimeoutSeconds:
                Argument."Result Integer" := 300;
            ProcType::GetDefaultMaxTokens:
                Argument."Result Integer" := 16384;
            ProcType::GetContextWindowChars:
                Argument."Result Integer" := 160000;
            ProcType::GetDefaultSkillUrl:
                Argument.SetResultText('');
            ProcType::GetDefaultSkillText:
                Argument.SetResultText('');
        end;
    end;

    local procedure CheckIsConfigured(var Argument: Record "Bifrost Chat Argument ori" temporary): Boolean
    begin
        exit(ProviderBase.IsConfigured(Argument, DefaultBaseUrlTok));
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
        ConfigJson.Add('model', ProviderBase.GetModel(Argument, DefaultModelTok));
        ConfigJson.Add('baseUrl', ProviderBase.GetBaseUrl(Argument, DefaultBaseUrlTok));
        ConfigJson.Add('timeoutMs', ProviderBase.GetTimeoutMs(Argument, 300000));
        ConfigJson.Add('maxTokens', ProviderBase.GetMaxTokens(Argument, 16384));
        ConfigJson.WriteTo(ConfigText);
        exit(ConfigText);
    end;

    local procedure DoSendChatMessage(var Argument: Record "Bifrost Chat Argument ori" temporary): Text
    var
        AnthropicProxy: Codeunit "Anthropic LangModel Proxy ori";
    begin
        exit(AnthropicProxy.SendChatMessage(Argument, Argument.GetPayload()));
    end;

    [NonDebuggable]
    local procedure DoCompletePrompt(var Argument: Record "Bifrost Chat Argument ori" temporary): Text
    var
        AnthropicProxy: Codeunit "Anthropic LangModel Proxy ori";
    begin
        exit(AnthropicProxy.CompletePrompt(Argument, Argument.GetPayload()));
    end;

    local procedure DoContinueWithToolResults(var Argument: Record "Bifrost Chat Argument ori" temporary): Text
    var
        AnthropicProxy: Codeunit "Anthropic LangModel Proxy ori";
    begin
        exit(AnthropicProxy.ContinueWithToolResults(Argument, Argument.GetConversationState(), Argument.GetToolResults()));
    end;

    local procedure DoGetAvailableModels(var Argument: Record "Bifrost Chat Argument ori" temporary): Boolean
    var
        TempNameValueBuffer: Record "Name/Value Buffer" temporary;
        AnthropicProxy: Codeunit "Anthropic LangModel Proxy ori";
        ModelsArray: JsonArray;
        ModelToken: JsonToken;
        ModelObject: JsonObject;
        BaseUrl: Text;
        IdValue: Text;
        DisplayName: Text;
        EntryNo: Integer;
    begin
        BaseUrl := ProviderBase.GetBaseUrl(Argument, DefaultBaseUrlTok);
        if BaseUrl = '' then
            exit(false);

        ModelsArray := AnthropicProxy.ListModels(BaseUrl, Argument.GetApiKey());

        foreach ModelToken in ModelsArray do begin
            ModelObject := ModelToken.AsObject();
            IdValue := GetJsonText(ModelObject, 'id');
            DisplayName := GetJsonText(ModelObject, 'display_name');
            if IdValue <> '' then begin
                EntryNo += 1;
                TempNameValueBuffer.Init();
                TempNameValueBuffer.ID := EntryNo;
                TempNameValueBuffer.Name := CopyStr(IdValue, 1, MaxStrLen(TempNameValueBuffer.Name));
                if DisplayName <> '' then
                    TempNameValueBuffer.Value := CopyStr(DisplayName, 1, MaxStrLen(TempNameValueBuffer.Value))
                else
                    TempNameValueBuffer.Value := CopyStr(IdValue, 1, MaxStrLen(TempNameValueBuffer.Value));
                TempNameValueBuffer.Insert();
            end;
        end;
        Argument.SetModels(TempNameValueBuffer);
        exit(EntryNo > 0);
    end;

    local procedure DoTestConnection(var Argument: Record "Bifrost Chat Argument ori" temporary): Boolean
    var
        AnthropicProxy: Codeunit "Anthropic LangModel Proxy ori";
        BaseUrl: Text;
        NoKeyErr: Label 'No API key configured. Enter a personal or shared API key.', Comment = 'is-IS=Enginn API-lykill stilltur. Sláðu inn persónulegan eða sameiginlegan API-lykil.';
        NoBaseUrlErr: Label 'No Base URL configured for this language model.', Comment = 'is-IS=Engin grunnslóð stillt fyrir þetta mállíkan.';
    begin
        if not Argument.HasApiKey() then begin
            Argument.SetErrorMessage(NoKeyErr);
            exit(false);
        end;
        BaseUrl := ProviderBase.GetBaseUrl(Argument, DefaultBaseUrlTok);
        if BaseUrl = '' then begin
            Argument.SetErrorMessage(NoBaseUrlErr);
            exit(false);
        end;
        AnthropicProxy.ListModels(BaseUrl, Argument.GetApiKey());
        exit(true);
    end;

    local procedure DoGetTokenUsage(var Argument: Record "Bifrost Chat Argument ori" temporary)
    var
        ResponseObject: JsonObject;
        UsageToken: JsonToken;
        UsageObject: JsonObject;
        InToken: JsonToken;
        OutToken: JsonToken;
    begin
        Argument."Input Tokens" := 0;
        Argument."Output Tokens" := 0;
        if not ResponseObject.ReadFrom(Argument.GetPayload()) then
            exit;
        if not ResponseObject.Get('usage', UsageToken) then
            exit;
        if not UsageToken.IsObject() then
            exit;
        UsageObject := UsageToken.AsObject();
        if UsageObject.Get('input_tokens', InToken) then
            Argument."Input Tokens" := InToken.AsValue().AsInteger();
        if UsageObject.Get('output_tokens', OutToken) then
            Argument."Output Tokens" := OutToken.AsValue().AsInteger();
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
