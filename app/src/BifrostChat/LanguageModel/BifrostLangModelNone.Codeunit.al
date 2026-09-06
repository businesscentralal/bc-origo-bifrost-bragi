namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

/// <summary>
/// Default no-op implementation for language models that do not override the chat provider.
/// Delegates to the user-level provider selection.
/// </summary>
codeunit 10035389 "Bifrost LangModel None ori" implements "Bifrost LangModel Provider ori"
{
    Access = Internal;

    procedure Execute(var Argument: Record "Bifrost Chat Argument ori" temporary)
    var
        ProcType: Enum "Bifrost Chat Proc. Type ori";
    begin
        ProcType := Argument."Procedure Type";
        case ProcType of
            ProcType::IsConfigured:
                Argument."Result Boolean" := false;
            ProcType::BuildConfigJson:
                Argument.SetResultText(BuildDisabledConfig());
            ProcType::SendChatMessage,
            ProcType::ContinueWithToolResults:
                Argument.SetResultText(BuildErrorJson());
            ProcType::GetAvailableModels:
                Argument."Result Boolean" := false;
            ProcType::TestConnection:
                begin
                    Argument."Result Boolean" := false;
                    Argument.SetErrorMessage(NoProviderErr);
                end;
            ProcType::GetTokenUsage:
                begin
                    Argument."Input Tokens" := 0;
                    Argument."Output Tokens" := 0;
                end;
            ProcType::GetProviderName:
                Argument.SetResultText('None');
            ProcType::RequiresApiKey,
            ProcType::HasServiceKeyPermission,
            ProcType::SupportsSplitToolExecution,
            ProcType::SupportsModelSelection,
            ProcType::SupportsToolCalling,
            ProcType::HasExternalEndpoint:
                Argument."Result Boolean" := false;
            ProcType::GetApiKeyLabel,
            ProcType::GetApiKeyInstruction,
            ProcType::GetApiKeyPlaceholder,
            ProcType::GetApiKeyDocsUrl,
            ProcType::GetApiKeyDocsLinkText,
            ProcType::GetServiceKeyDescription,
            ProcType::GetDefaultBaseUrl,
            ProcType::GetDefaultModel,
            ProcType::GetDefaultSkillUrl,
            ProcType::GetDefaultSkillText:
                Argument.SetResultText('');
            ProcType::GetMaxToolCount,
            ProcType::GetDefaultTimeoutSeconds,
            ProcType::GetDefaultMaxTokens,
            ProcType::GetContextWindowChars:
                Argument."Result Integer" := 0;
        end;
    end;

    var
        NoProviderErr: Label 'No provider configured for this language model.', Comment = 'is-IS=Enginn veitandi stilltur fyrir þetta mállíkan.';
        NoProviderMsgErr: Label 'No chat provider configured on the language model.', Comment = 'is-IS=Enginn spjallveitandi stilltur á mállíkaninu.';
        DisabledMsg: Label 'Bifrost Chat is disabled. Assign a Language Model with a provider in your Bifrost User Setup to enable chat.', Comment = 'is-IS=Spjalla við Bifröst er óvirkt. Úthlutaðu mállíkani með veitanda í Bifröst notandauppsetningu til að virkja spjall.';

    local procedure BuildDisabledConfig(): Text
    var
        ConfigJson: JsonObject;
        ConfigText: Text;
    begin
        ConfigJson.Add('disabled', true);
        ConfigJson.Add('disabledMessage', DisabledMsg);
        ConfigJson.WriteTo(ConfigText);
        exit(ConfigText);
    end;

    local procedure BuildErrorJson(): Text
    var
        ErrorJson: JsonObject;
        ResponseText: Text;
    begin
        ErrorJson.Add('error', NoProviderMsgErr);
        ErrorJson.WriteTo(ResponseText);
        exit(ResponseText);
    end;
}
