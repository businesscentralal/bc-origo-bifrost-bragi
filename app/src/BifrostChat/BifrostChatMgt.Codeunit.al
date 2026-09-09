namespace Origo.Bifrost.Bragi;
using Microsoft.Utilities;

using Origo.Bifrost;

/// <summary>
/// Public entry point for Bifrost Chat operations. Resolves the active provider
/// from the user's assigned Bifrost Language Model (or the default language model) and delegates
/// through the "Bifrost LangModel Provider ori" interface.
/// </summary>
codeunit 10035382 "Bifrost Chat Mgt ori"
{
    Access = Public;

    /// <summary>
    /// Returns whether the Bifrost Chat UI should be shown for the current user.
    /// Requires Bifrost Chat permission and a role assignment (explicit or default).
    /// </summary>
    procedure ShowBifrostChat(): Boolean
    var
        BifrostLanguageModel: Record "Bifrost Language Model ori";
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        Provider: Interface "Bifrost LangModel Provider ori";
    begin
        if not HasChatPermission() then
            exit(false);
        if not HasLanguageModelAssignment() then begin
            BifrostLanguageModel.SetRange(Default, true);
            if BifrostLanguageModel.IsEmpty() then
                exit(false);
        end;
        Provider := GetLangModelProviderWithModel(BifrostLanguageModel);
        BuildArgument(BifrostLanguageModel, TempArgument);
        ExecuteProvider(Provider, TempArgument, TempArgument."Procedure Type"::IsConfigured);
        exit(TempArgument."Result Boolean");
    end;

    /// <summary>
    /// Returns whether the current user holds the Bifrost Chat permission set.
    /// </summary>
    procedure HasChatPermission(): Boolean
    var
        ChatGate: Record "Chat Gate ori";
    begin
        exit(ChatGate.WritePermission());
    end;

    /// <summary>
    /// Returns whether the current user has a language model explicitly assigned in user setup.
    /// </summary>
    procedure HasLanguageModelAssignment(): Boolean
    var
        BifrostUserSetup: Record "User Setup ori";
    begin
        BifrostUserSetup.SetLoadFields("Bifrost Language Model Code");
        if BifrostUserSetup.Get(UserSecurityId()) and (BifrostUserSetup."Bifrost Language Model Code" <> '') then
            exit(true);
        exit(false);
    end;

    /// <summary>
    /// Resolves the chat provider from the user's language model, the default language model, or None.
    /// </summary>
    procedure GetLangModelProvider() Provider: Interface "Bifrost LangModel Provider ori"
    var
        BifrostLanguageModel: Record "Bifrost Language Model ori";
    begin
        exit(GetLangModelProviderWithModel(BifrostLanguageModel));
    end;

    /// <summary>
    /// Resolves the provider for an explicit language model code, falling back to the user's default.
    /// </summary>
    procedure GetLangModelProvider(RoleCode: Code[20]) Provider: Interface "Bifrost LangModel Provider ori"
    var
        BifrostLanguageModel: Record "Bifrost Language Model ori";
    begin
        if RoleCode <> '' then
            if BifrostLanguageModel.Get(RoleCode) then begin
                Provider := BifrostLanguageModel."Chat Provider";
                exit;
            end;
        exit(GetLangModelProviderWithModel(BifrostLanguageModel));
    end;

    /// <summary>
    /// Resolves the provider and returns the resolved role record.
    /// </summary>
    procedure GetLangModelProviderWithModel(var ResolvedRole: Record "Bifrost Language Model ori") Provider: Interface "Bifrost LangModel Provider ori"
    var
        BifrostUserSetup: Record "User Setup ori";
        BifrostLanguageModel: Record "Bifrost Language Model ori";
        TestCtx: Codeunit "Bifrost LangModel Test Ctx ori";
    begin
        // Role card "Try It" override
        if TestCtx.TryGetLanguageModel(BifrostLanguageModel) then begin
            ResolvedRole := BifrostLanguageModel;
            Provider := BifrostLanguageModel."Chat Provider";
            exit;
        end;

        BifrostUserSetup.SetLoadFields("Bifrost Language Model Code");
        if BifrostUserSetup.Get(UserSecurityId()) and (BifrostUserSetup."Bifrost Language Model Code" <> '') then
            if BifrostLanguageModel.Get(BifrostUserSetup."Bifrost Language Model Code") then begin
                ResolvedRole := BifrostLanguageModel;
                Provider := BifrostLanguageModel."Chat Provider";
                exit;
            end;


        // Fall back to the default language model
        BifrostLanguageModel.SetRange(Default, true);
        if BifrostLanguageModel.FindFirst() then begin
            ResolvedRole := BifrostLanguageModel;
            Provider := BifrostLanguageModel."Chat Provider";
            exit;
        end;

        // No role found — use None (disabled)
        Provider := Enum::"Bifrost LangModel Prov. ori"::None;
    end;

    /// <summary>
    /// Delegates to the current provider's BuildConfigJson.
    /// </summary>
    /// <returns>Serialized JSON config text for the chat control add-in.</returns>
    [NonDebuggable]
    procedure BuildConfigJson(): Text
    var
        BifrostSetup: Record "Setup ori";
        BifrostLanguageModel: Record "Bifrost Language Model ori";
        BifrostUserSetup: Record "User Setup ori";
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        Provider: Interface "Bifrost LangModel Provider ori";
        ServiceKeyTok: Label 'Bifrost_Chat_Svc_', Locked = true;
        ConfigObject: JsonObject;
        ConfigText: Text;
        RoleSkill: Text;
    begin
        Provider := GetLangModelProviderWithModel(BifrostLanguageModel);
        BuildArgument(BifrostLanguageModel, TempArgument);
        ExecuteProvider(Provider, TempArgument, TempArgument."Procedure Type"::BuildConfigJson);
        ConfigText := TempArgument.GetResultText();
        if ConfigObject.ReadFrom(ConfigText) then begin
            BifrostSetup.GetRecordOnce();
            SetJsonProperty(ConfigObject, 'debug', BifrostSetup."Request Debug Mode");
            SetJsonProperty(ConfigObject, 'hasServiceKey', IsolatedStorage.Contains(ServiceKeyTok + Format(BifrostLanguageModel.SystemId, 0, 4), DataScope::Company));
            SetJsonProperty(ConfigObject, 'canManageServiceKey', GetProviderBool(Provider, TempArgument, TempArgument."Procedure Type"::HasServiceKeyPermission));
            SetJsonProperty(ConfigObject, 'requiresApiKey', GetProviderBool(Provider, TempArgument, TempArgument."Procedure Type"::RequiresApiKey));
            SetJsonProperty(ConfigObject, 'apiKeyLabel', GetProviderText(Provider, TempArgument, TempArgument."Procedure Type"::GetApiKeyLabel));
            SetJsonProperty(ConfigObject, 'apiKeyInstruction', GetProviderText(Provider, TempArgument, TempArgument."Procedure Type"::GetApiKeyInstruction));
            SetJsonProperty(ConfigObject, 'apiKeyPlaceholder', GetProviderText(Provider, TempArgument, TempArgument."Procedure Type"::GetApiKeyPlaceholder));
            SetJsonProperty(ConfigObject, 'apiKeyDocsUrl', GetProviderText(Provider, TempArgument, TempArgument."Procedure Type"::GetApiKeyDocsUrl));
            SetJsonProperty(ConfigObject, 'apiKeyDocsLinkText', GetProviderText(Provider, TempArgument, TempArgument."Procedure Type"::GetApiKeyDocsLinkText));
            SetJsonProperty(ConfigObject, 'serviceKeyDescription', GetProviderText(Provider, TempArgument, TempArgument."Procedure Type"::GetServiceKeyDescription));
            SetJsonProperty(ConfigObject, 'supportsToolLoop', GetProviderBool(Provider, TempArgument, TempArgument."Procedure Type"::SupportsSplitToolExecution));

            // Inject the language model's skill content so the JS sends it in every payload
            BifrostUserSetup.SetLoadFields("Bifrost Language Model Code");
            if BifrostUserSetup.Get(UserSecurityId()) and (BifrostUserSetup."Bifrost Language Model Code" <> '') then
                if BifrostLanguageModel.Get(BifrostUserSetup."Bifrost Language Model Code") then begin
                    RoleSkill := BifrostLanguageModel.GetSkill();
                    if RoleSkill <> '' then
                        SetJsonProperty(ConfigObject, 'contextSkill', RoleSkill);
                end;

            ConfigObject.WriteTo(ConfigText);
        end;
        exit(ConfigText);
    end;

    /// <summary>
    /// Delegates to the current provider's SaveApiKey.
    /// </summary>
    /// <param name="ApiKey">The API key text entered by the user.</param>
    [NonDebuggable]
    procedure SaveApiKey(ApiKey: Text)
    var
        BifrostLanguageModel: Record "Bifrost Language Model ori";
        UserKeyTok: Label 'Bifrost_Chat_Usr_', Locked = true;
        StorageKey: Text;
    begin
        GetLangModelProviderWithModel(BifrostLanguageModel);
        StorageKey := UserKeyTok + Format(BifrostLanguageModel.SystemId, 0, 4) + '_' + Format(UserSecurityId(), 0, 4);
        if ApiKey = '' then begin
            if IsolatedStorage.Contains(StorageKey, DataScope::Company) then
                IsolatedStorage.Delete(StorageKey, DataScope::Company);
        end else
            IsolatedStorage.Set(StorageKey, ApiKey, DataScope::Company);
    end;

    /// <summary>
    /// Delegates to the current provider's SaveServiceApiKey.
    /// </summary>
    [NonDebuggable]
    procedure SaveServiceApiKey(ApiKey: Text)
    var
        BifrostLanguageModel: Record "Bifrost Language Model ori";
        ServiceKeyTok: Label 'Bifrost_Chat_Svc_', Locked = true;
        StorageKey: Text;
    begin
        GetLangModelProviderWithModel(BifrostLanguageModel);
        StorageKey := ServiceKeyTok + Format(BifrostLanguageModel.SystemId, 0, 4);
        if ApiKey = '' then begin
            if IsolatedStorage.Contains(StorageKey, DataScope::Company) then
                IsolatedStorage.Delete(StorageKey, DataScope::Company);
        end else
            IsolatedStorage.Set(StorageKey, ApiKey, DataScope::Company);
    end;

    /// <summary>
    /// Delegates to the current provider's SendChatMessage.
    /// </summary>
    /// <param name="PayloadJson">JSON payload produced by the chat control.</param>
    /// <returns>JSON response text to forward back to the control.</returns>
    [NonDebuggable]
    procedure SendChatMessage(PayloadJson: Text): Text
    var
        BifrostLanguageModel: Record "Bifrost Language Model ori";
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        Provider: Interface "Bifrost LangModel Provider ori";
    begin
        Provider := GetLangModelProviderWithModel(BifrostLanguageModel);
        BuildArgument(BifrostLanguageModel, TempArgument);
        TempArgument.SetPayload(PayloadJson);
        ExecuteProvider(Provider, TempArgument, TempArgument."Procedure Type"::SendChatMessage);
        exit(TempArgument.GetResultText());
    end;

    /// <summary>
    /// Delegates to the current provider's ContinueWithToolResults.
    /// </summary>
    [NonDebuggable]
    procedure ContinueWithToolResults(ConversationState: Text; ToolResultsJson: Text): Text
    var
        BifrostLanguageModel: Record "Bifrost Language Model ori";
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        Provider: Interface "Bifrost LangModel Provider ori";
    begin
        Provider := GetLangModelProviderWithModel(BifrostLanguageModel);
        BuildArgument(BifrostLanguageModel, TempArgument);
        TempArgument.SetConversationState(ConversationState);
        TempArgument.SetToolResults(ToolResultsJson);
        ExecuteProvider(Provider, TempArgument, TempArgument."Procedure Type"::ContinueWithToolResults);
        exit(TempArgument.GetResultText());
    end;

    /// <summary>
    /// Delegates to the current provider's GetAvailableModels.
    /// </summary>
    /// <param name="TempNameValueBuffer">Temporary buffer to receive the model list.</param>
    /// <returns>True when at least one model was returned.</returns>
    procedure GetAvailableModels(var TempNameValueBuffer: Record "Name/Value Buffer" temporary): Boolean
    var
        BifrostLanguageModel: Record "Bifrost Language Model ori";
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        Provider: Interface "Bifrost LangModel Provider ori";
    begin
        Provider := GetLangModelProviderWithModel(BifrostLanguageModel);
        BuildArgument(BifrostLanguageModel, TempArgument);
        ExecuteProvider(Provider, TempArgument, TempArgument."Procedure Type"::GetAvailableModels);
        TempArgument.GetModels(TempNameValueBuffer);
        exit(TempArgument."Result Boolean");
    end;

    /// <summary>
    /// Delegates to the current provider's ClearCredentials.
    /// </summary>
    procedure ClearCredentials()
    var
        BifrostLanguageModel: Record "Bifrost Language Model ori";
        UserKeyTok: Label 'Bifrost_Chat_Usr_', Locked = true;
        StorageKey: Text;
    begin
        GetLangModelProviderWithModel(BifrostLanguageModel);
        StorageKey := UserKeyTok + Format(BifrostLanguageModel.SystemId, 0, 4) + '_' + Format(UserSecurityId(), 0, 4);
        if IsolatedStorage.Contains(StorageKey, DataScope::Company) then
            IsolatedStorage.Delete(StorageKey, DataScope::Company);
    end;

    [NonDebuggable]
    local procedure BuildArgument(var BifrostLanguageModel: Record "Bifrost Language Model ori"; var TempArgument: Record "Bifrost Chat Argument ori" temporary)
    var
        BifrostSetup: Record "Setup ori";
        BifrostUserSetup: Record "User Setup ori";
        UserKeyTok: Label 'Bifrost_Chat_Usr_', Locked = true;
        ServiceKeyTok: Label 'Bifrost_Chat_Svc_', Locked = true;
        ApiKeyValue: Text;
    begin
        TempArgument.Init();
        TempArgument."Language Model SystemId" := BifrostLanguageModel.SystemId;
        TempArgument."Base URL" := BifrostLanguageModel."Base URL";
        TempArgument.Model := BifrostLanguageModel.Model;
        TempArgument."Timeout Ms" := BifrostLanguageModel."Timeout Seconds" * 1000;
        TempArgument."Max Tokens" := BifrostLanguageModel."Max Tokens";
        TempArgument."Chat Path" := BifrostLanguageModel."Chat Path";
        TempArgument."Models Path" := BifrostLanguageModel."Models Path";
        TempArgument.SetSkill(BifrostLanguageModel.GetSkill());

        BifrostUserSetup.SetLoadFields("User Security ID");
        if BifrostUserSetup.Get(UserSecurityId()) then
            TempArgument.SetUserPrompt(BifrostUserSetup.GetSystemPrompt());

        BifrostSetup.SetLoadFields("Request Debug Mode");
        if BifrostSetup.Get() then
            TempArgument."Debug Mode" := BifrostSetup."Request Debug Mode";

        if IsolatedStorage.Get(UserKeyTok + Format(BifrostLanguageModel.SystemId, 0, 4) + '_' + Format(UserSecurityId(), 0, 4), DataScope::Company, ApiKeyValue) then
            if ApiKeyValue <> '' then begin
                TempArgument.SetApiKey(ApiKeyValue);
                exit;
            end;
        if IsolatedStorage.Get(ServiceKeyTok + Format(BifrostLanguageModel.SystemId, 0, 4), DataScope::Company, ApiKeyValue) then
            TempArgument.SetApiKey(ApiKeyValue);
    end;

    local procedure ExecuteProvider(var Provider: Interface "Bifrost LangModel Provider ori"; var TempArgument: Record "Bifrost Chat Argument ori" temporary; ProcType: Enum "Bifrost Chat Proc. Type ori")
    begin
        TempArgument."Procedure Type" := ProcType;
        TempArgument."Result Boolean" := false;
        TempArgument."Result Integer" := 0;
        TempArgument.SetResultText('');
        TempArgument.SetErrorMessage('');
        Provider.Execute(TempArgument);
    end;

    local procedure GetProviderBool(var Provider: Interface "Bifrost LangModel Provider ori"; var TempArgument: Record "Bifrost Chat Argument ori" temporary; ProcType: Enum "Bifrost Chat Proc. Type ori"): Boolean
    begin
        ExecuteProvider(Provider, TempArgument, ProcType);
        exit(TempArgument."Result Boolean");
    end;

    local procedure GetProviderText(var Provider: Interface "Bifrost LangModel Provider ori"; var TempArgument: Record "Bifrost Chat Argument ori" temporary; ProcType: Enum "Bifrost Chat Proc. Type ori"): Text
    begin
        ExecuteProvider(Provider, TempArgument, ProcType);
        exit(TempArgument.GetResultText());
    end;

    local procedure SetJsonProperty(var JObject: JsonObject; PropertyName: Text; Value: Boolean)
    begin
        if JObject.Contains(PropertyName) then
            JObject.Replace(PropertyName, Value)
        else
            JObject.Add(PropertyName, Value);
    end;

    local procedure SetJsonProperty(var JObject: JsonObject; PropertyName: Text; Value: Text)
    var
        JValue: JsonValue;
    begin
        JValue.SetValue(Value);
        if JObject.Contains(PropertyName) then
            JObject.Replace(PropertyName, JValue)
        else
            JObject.Add(PropertyName, JValue);
    end;
}
