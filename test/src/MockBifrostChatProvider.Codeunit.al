namespace Origo.Bifrost.LanguageModels.Test;
using Microsoft.Utilities;
using Origo.Bifrost;

using Origo.Bifrost.LanguageModels;

/// <summary>
/// Configurable mock implementation of the "Bifrost LangModel Provider ori" interface for unit testing
/// the dispatcher in "Bifrost Chat Mgt ori". SingleInstance so tests can pre-configure return values
/// and inspect which methods were called and with which arguments.
/// </summary>
codeunit 96001 "Mock Bifrost Chat Provider" implements "Bifrost LangModel Provider ori"
{
    Access = Internal;
    SingleInstance = true;

    var
        LastSendPayload: Text;
        LastConversationState: Text;
        LastToolResultsJson: Text;
        LastBaseUrl: Text;
        LastModel: Text;
        LastChatPath: Text;
        LastModelsPath: Text;
        LastApiKey: Text;
        LastTimeoutMs: Integer;
        LastMaxTokens: Integer;
        LastDebugMode: Boolean;
        SendResponseValue: Text;
        ContinueResponseValue: Text;
        ConfigJsonValue: Text;
        IsConfiguredValue: Boolean;
        IsConfiguredCalled: Boolean;
        BuildConfigCalled: Boolean;
        SendChatMessageCalled: Boolean;
        ContinueWithToolResultsCalled: Boolean;
        GetAvailableModelsCalled: Boolean;
        ModelCount: Integer;

    procedure Execute(var Argument: Record "Bifrost Chat Argument ori" temporary)
    var
        ProcType: Enum "Bifrost Chat Proc. Type ori";
    begin
        ProcType := Argument."Procedure Type";
        case ProcType of
            ProcType::IsConfigured:
                begin
                    IsConfiguredCalled := true;
                    Argument."Result Boolean" := IsConfiguredValue;
                end;
            ProcType::BuildConfigJson:
                begin
                    BuildConfigCalled := true;
                    Argument.SetResultText(ConfigJsonValue);
                end;
            ProcType::SendChatMessage:
                begin
                    SendChatMessageCalled := true;
                    LastSendPayload := Argument.GetPayload();
                    CaptureArgument(Argument);
                    Argument.SetResultText(SendResponseValue);
                end;
            ProcType::ContinueWithToolResults:
                begin
                    ContinueWithToolResultsCalled := true;
                    LastConversationState := Argument.GetConversationState();
                    LastToolResultsJson := Argument.GetToolResults();
                    Argument.SetResultText(ContinueResponseValue);
                end;
            ProcType::GetAvailableModels:
                begin
                    GetAvailableModelsCalled := true;
                    PopulateModels(Argument);
                end;
            ProcType::TestConnection:
                Argument."Result Boolean" := true;
            ProcType::GetTokenUsage:
                begin
                    Argument."Input Tokens" := 0;
                    Argument."Output Tokens" := 0;
                end;
            ProcType::GetProviderName:
                Argument.SetResultText('Mock');
            ProcType::RequiresApiKey:
                Argument."Result Boolean" := true;
            ProcType::HasServiceKeyPermission:
                Argument."Result Boolean" := false;
            ProcType::SupportsSplitToolExecution:
                Argument."Result Boolean" := true;
            ProcType::SupportsModelSelection:
                Argument."Result Boolean" := true;
            ProcType::SupportsToolCalling:
                Argument."Result Boolean" := true;
            ProcType::HasExternalEndpoint:
                Argument."Result Boolean" := true;
            ProcType::GetApiKeyLabel:
                Argument.SetResultText('API Key');
            ProcType::GetApiKeyInstruction:
                Argument.SetResultText('Enter your mock provider API key.');
            ProcType::GetApiKeyPlaceholder:
                Argument.SetResultText('sk-mock-...');
            ProcType::GetApiKeyDocsUrl:
                Argument.SetResultText('https://mock.test/keys');
            ProcType::GetApiKeyDocsLinkText:
                Argument.SetResultText('Get a mock key');
            ProcType::GetServiceKeyDescription:
                Argument.SetResultText('Shared by all users in this company without a personal key.');
            ProcType::GetDefaultBaseUrl:
                Argument.SetResultText('https://api.mock.test');
            ProcType::GetDefaultModel:
                Argument.SetResultText('mock-model-v1');
            ProcType::GetDefaultSkillUrl,
            ProcType::GetDefaultSkillText:
                Argument.SetResultText('');
            ProcType::GetMaxToolCount:
                Argument."Result Integer" := 0;
            ProcType::GetDefaultTimeoutSeconds:
                Argument."Result Integer" := 120;
            ProcType::GetDefaultMaxTokens:
                Argument."Result Integer" := 4096;
            ProcType::GetContextWindowChars:
                Argument."Result Integer" := 80000;
        end;
    end;

    local procedure PopulateModels(var Argument: Record "Bifrost Chat Argument ori" temporary)
    var
        TempNameValueBuffer: Record "Name/Value Buffer" temporary;
        i: Integer;
    begin
        for i := 1 to ModelCount do begin
            TempNameValueBuffer.Init();
            TempNameValueBuffer.ID := i;
            TempNameValueBuffer.Name := CopyStr('model-' + Format(i), 1, MaxStrLen(TempNameValueBuffer.Name));
            TempNameValueBuffer.Value := CopyStr('Model ' + Format(i), 1, MaxStrLen(TempNameValueBuffer.Value));
            TempNameValueBuffer.Insert();
        end;
        Argument.SetModels(TempNameValueBuffer);
        Argument."Result Boolean" := ModelCount > 0;
    end;

    /// <summary>Resets all mock state — call from each test's Initialize.</summary>
    procedure Reset()
    begin
        LastSendPayload := '';
        LastConversationState := '';
        LastToolResultsJson := '';
        LastBaseUrl := '';
        LastModel := '';
        LastChatPath := '';
        LastModelsPath := '';
        LastApiKey := '';
        LastTimeoutMs := 0;
        LastMaxTokens := 0;
        LastDebugMode := false;
        SendResponseValue := '';
        ContinueResponseValue := '';
        ConfigJsonValue := '';
        IsConfiguredValue := false;
        IsConfiguredCalled := false;
        BuildConfigCalled := false;
        SendChatMessageCalled := false;
        ContinueWithToolResultsCalled := false;
        GetAvailableModelsCalled := false;
        ModelCount := 0;
    end;

    procedure SetIsConfigured(Value: Boolean)
    begin
        IsConfiguredValue := Value;
    end;

    procedure SetConfigJson(Json: Text)
    begin
        ConfigJsonValue := Json;
    end;

    procedure SetSendResponse(ResponseJson: Text)
    begin
        SendResponseValue := ResponseJson;
    end;

    procedure SetContinueResponse(ResponseJson: Text)
    begin
        ContinueResponseValue := ResponseJson;
    end;

    procedure SetModelCount(Count: Integer)
    begin
        ModelCount := Count;
    end;

    procedure GetLastSendPayload(): Text
    begin
        exit(LastSendPayload);
    end;

    [NonDebuggable]
    local procedure CaptureArgument(var Argument: Record "Bifrost Chat Argument ori" temporary)
    begin
        LastBaseUrl := Argument."Base URL";
        LastModel := Argument.Model;
        LastChatPath := Argument."Chat Path";
        LastModelsPath := Argument."Models Path";
        LastApiKey := Argument.GetApiKeyIndicator();
        LastTimeoutMs := Argument."Timeout Ms";
        LastMaxTokens := Argument."Max Tokens";
        LastDebugMode := Argument."Debug Mode";
    end;

    procedure GetLastBaseUrl(): Text
    begin
        exit(LastBaseUrl);
    end;

    procedure GetLastModel(): Text
    begin
        exit(LastModel);
    end;

    procedure GetLastChatPath(): Text
    begin
        exit(LastChatPath);
    end;

    procedure GetLastModelsPath(): Text
    begin
        exit(LastModelsPath);
    end;

    [NonDebuggable]
    procedure GetLastApiKey(): Text
    begin
        exit(LastApiKey);
    end;

    procedure GetLastTimeoutMs(): Integer
    begin
        exit(LastTimeoutMs);
    end;

    procedure GetLastMaxTokens(): Integer
    begin
        exit(LastMaxTokens);
    end;

    procedure GetLastDebugMode(): Boolean
    begin
        exit(LastDebugMode);
    end;

    procedure WasIsConfiguredCalled(): Boolean
    begin
        exit(IsConfiguredCalled);
    end;

    procedure WasBuildConfigCalled(): Boolean
    begin
        exit(BuildConfigCalled);
    end;

    procedure WasSendChatMessageCalled(): Boolean
    begin
        exit(SendChatMessageCalled);
    end;

    procedure WasContinueWithToolResultsCalled(): Boolean
    begin
        exit(ContinueWithToolResultsCalled);
    end;

    procedure GetLastConversationState(): Text
    begin
        exit(LastConversationState);
    end;

    procedure GetLastToolResultsJson(): Text
    begin
        exit(LastToolResultsJson);
    end;

    procedure WasGetAvailableModelsCalled(): Boolean
    begin
        exit(GetAvailableModelsCalled);
    end;
}
