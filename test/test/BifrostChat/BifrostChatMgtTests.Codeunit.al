#pragma warning disable AL0432
namespace Origo.Bifrost.LanguageModels.Test;
using Microsoft.Utilities;
using Origo.Bifrost;

using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests for the "Bifrost Chat Mgt ori" dispatcher. Verifies that the provider resolved from
/// the user's Bifrost Language Model (via GetLangModelProvider) handles each interface call, using the
/// configurable "Mock Bifrost Chat Provider" registered via the test enumextension.
/// </summary>
codeunit 96002 "Bifrost Chat Mgt Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure GetLangModelProvider_NoSetup_FallsBackToNone()
    var
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
    begin
        // [SCENARIO] When no user setup or default role exists, ShowBifrostChat returns false.
        Initialize();
        DeleteCurrentUserSetup();

        Assert.IsFalse(BifrostChatMgt.ShowBifrostChat(), 'ShowBifrostChat should be false with no setup or default role.');
        Assert.IsFalse(MockProvider.WasIsConfiguredCalled(), 'Mock provider should not be invoked.');
    end;

    [Test]
    procedure GetLangModelProvider_DefaultRole_NoneProvider_ReturnsFalse()
    var
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
    begin
        // [SCENARIO] Default role with None provider returns false.
        Initialize();
        DeleteCurrentUserSetup();
        CreateRole('DEFAULT', true, Enum::"Bifrost LangModel Prov. ori"::None);

        Assert.IsFalse(BifrostChatMgt.ShowBifrostChat(), 'ShowBifrostChat should be false when default role has None provider.');
        Assert.IsFalse(MockProvider.WasIsConfiguredCalled(), 'Mock should not be invoked for None provider.');
    end;

    [Test]
    procedure ShowBifrostChat_RoleMock_ConfiguredTrue_ReturnsTrue()
    var
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
    begin
        // [SCENARIO] ShowBifrostChat returns true when the role's provider reports configured.
        Initialize();
        SetupUserWithRole('MOCK-ROLE');
        CreateRole('MOCK-ROLE', false, Enum::"Bifrost LangModel Prov. ori"::Mock);
        MockProvider.SetIsConfigured(true);

        Assert.IsTrue(BifrostChatMgt.ShowBifrostChat(), 'ShowBifrostChat should return true when mock reports configured.');
        Assert.IsTrue(MockProvider.WasIsConfiguredCalled(), 'IsConfigured should have been called on mock.');
    end;

    [Test]
    procedure ShowBifrostChat_RoleMock_ConfiguredFalse_ReturnsFalse()
    var
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
    begin
        // [SCENARIO] ShowBifrostChat returns false when the role's provider reports not configured.
        Initialize();
        SetupUserWithRole('MOCK-ROLE');
        CreateRole('MOCK-ROLE', false, Enum::"Bifrost LangModel Prov. ori"::Mock);
        MockProvider.SetIsConfigured(false);

        Assert.IsFalse(BifrostChatMgt.ShowBifrostChat(), 'ShowBifrostChat should return false when mock reports not configured.');
        Assert.IsTrue(MockProvider.WasIsConfiguredCalled(), 'IsConfigured should have been called on mock.');
    end;

    [Test]
    procedure BuildConfigJson_RoleMock_ReturnsMockConfigWithEnrichedFields()
    var
        BifrostSetup: Record "Setup ori";
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ConfigJson: JsonObject;
        ConfigText: Text;
        Token: JsonToken;
    begin
        // [SCENARIO] BuildConfigJson enriches the provider config with metadata fields.
        Initialize();
        BifrostSetup.GetRecordOnce();
        BifrostSetup."Request Debug Mode" := false;
        BifrostSetup.Modify();

        SetupUserWithRole('MOCK-ROLE');
        CreateRole('MOCK-ROLE', false, Enum::"Bifrost LangModel Prov. ori"::Mock);
        MockProvider.SetConfigJson('{"apiKey":"abc","model":"mock-model"}');

        ConfigText := BifrostChatMgt.BuildConfigJson();
        Assert.IsTrue(ConfigJson.ReadFrom(ConfigText), 'Should return valid JSON.');
        Assert.IsTrue(MockProvider.WasBuildConfigCalled(), 'BuildConfigJson should have been called on mock.');

        // Provider base fields preserved
        ConfigJson.Get('apiKey', Token);
        Assert.AreEqual('abc', Token.AsValue().AsText(), 'apiKey should be preserved.');
        ConfigJson.Get('model', Token);
        Assert.AreEqual('mock-model', Token.AsValue().AsText(), 'model should be preserved.');

        // Enriched fields
        ConfigJson.Get('debug', Token);
        Assert.IsFalse(Token.AsValue().AsBoolean(), 'debug should be false.');
        ConfigJson.Get('hasServiceKey', Token);
        Assert.IsFalse(Token.AsValue().AsBoolean(), 'hasServiceKey from mock is false.');
        ConfigJson.Get('canManageServiceKey', Token);
        Assert.IsFalse(Token.AsValue().AsBoolean(), 'canManageServiceKey from mock is false.');
        ConfigJson.Get('requiresApiKey', Token);
        Assert.IsTrue(Token.AsValue().AsBoolean(), 'requiresApiKey from mock is true.');
        ConfigJson.Get('apiKeyLabel', Token);
        Assert.AreEqual('API Key', Token.AsValue().AsText(), 'apiKeyLabel from mock.');
        ConfigJson.Get('supportsToolLoop', Token);
        Assert.IsTrue(Token.AsValue().AsBoolean(), 'supportsToolLoop from mock is true.');
    end;

    [Test]
    procedure BuildConfigJson_NoneProvider_ReturnsDisabledFlag()
    var
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
        ConfigJson: JsonObject;
        DisabledToken: JsonToken;
    begin
        // [SCENARIO] None provider returns disabled config.
        Initialize();
        DeleteCurrentUserSetup();
        CreateRole('DEFAULT', true, Enum::"Bifrost LangModel Prov. ori"::None);

        Assert.IsTrue(ConfigJson.ReadFrom(BifrostChatMgt.BuildConfigJson()), 'Config should be valid JSON.');
        Assert.IsTrue(ConfigJson.Get('disabled', DisabledToken), 'Should contain disabled field.');
        Assert.IsTrue(DisabledToken.AsValue().AsBoolean(), 'disabled should be true.');
    end;

    [Test]
    procedure SendChatMessage_RoleMock_RoundTrips()
    var
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        PayloadJson: Text;
        ExpectedResponse: Text;
    begin
        // [SCENARIO] SendChatMessage forwards payload and returns provider response.
        Initialize();
        SetupUserWithRole('MOCK-ROLE');
        CreateRole('MOCK-ROLE', false, Enum::"Bifrost LangModel Prov. ori"::Mock);
        PayloadJson := '{"messages":[{"role":"user","content":"hi"}]}';
        ExpectedResponse := '{"content":"hello back"}';
        MockProvider.SetSendResponse(ExpectedResponse);

        Assert.AreEqual(ExpectedResponse, BifrostChatMgt.SendChatMessage(PayloadJson), 'Should return mock response.');
        Assert.AreEqual(PayloadJson, MockProvider.GetLastSendPayload(), 'Mock should have received the payload.');
    end;

    [Test]
    procedure SendChatMessage_NoneProvider_ReturnsErrorJson()
    var
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
        ResponseJson: JsonObject;
        ResponseToken: JsonToken;
    begin
        // [SCENARIO] None provider returns error JSON from SendChatMessage.
        Initialize();
        DeleteCurrentUserSetup();
        CreateRole('DEFAULT', true, Enum::"Bifrost LangModel Prov. ori"::None);

        Assert.IsTrue(ResponseJson.ReadFrom(BifrostChatMgt.SendChatMessage('{}')), 'Response should be valid JSON.');
        Assert.IsTrue(ResponseJson.Get('error', ResponseToken), 'Response should contain error field.');
    end;

    [Test]
    procedure GetAvailableModels_RoleMock_PopulatesBuffer()
    var
        TempNameValueBuffer: Record "Name/Value Buffer" temporary;
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
    begin
        // [SCENARIO] GetAvailableModels populates buffer from role's provider.
        Initialize();
        SetupUserWithRole('MOCK-ROLE');
        CreateRole('MOCK-ROLE', false, Enum::"Bifrost LangModel Prov. ori"::Mock);
        MockProvider.SetModelCount(3);

        Assert.IsTrue(BifrostChatMgt.GetAvailableModels(TempNameValueBuffer), 'Should return true with models.');
        Assert.AreEqual(3, TempNameValueBuffer.Count(), 'Buffer should contain 3 models.');
    end;

    [Test]
    procedure GetAvailableModels_RoleMock_NoModels_ReturnsFalse()
    var
        TempNameValueBuffer: Record "Name/Value Buffer" temporary;
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
    begin
        // [SCENARIO] GetAvailableModels returns false when provider has no models.
        Initialize();
        SetupUserWithRole('MOCK-ROLE');
        CreateRole('MOCK-ROLE', false, Enum::"Bifrost LangModel Prov. ori"::Mock);
        MockProvider.SetModelCount(0);

        Assert.IsFalse(BifrostChatMgt.GetAvailableModels(TempNameValueBuffer), 'Should return false with no models.');
        Assert.AreEqual(0, TempNameValueBuffer.Count(), 'Buffer should be empty.');
    end;

    [Test]
    procedure GetLangModelProvider_DefaultRole_UsedWhenNoUserRole()
    var
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
    begin
        // [SCENARIO] When user has no role assigned, the default role's provider is used.
        Initialize();
        SetupUserWithRole('');
        CreateRole('DEFAULT', true, Enum::"Bifrost LangModel Prov. ori"::Mock);
        MockProvider.SetIsConfigured(true);

        Assert.IsTrue(BifrostChatMgt.ShowBifrostChat(), 'Should use default role when user has no role assigned.');
        Assert.IsTrue(MockProvider.WasIsConfiguredCalled(), 'Mock should be invoked via default role.');
    end;

    [Test]
    procedure GetLangModelProvider_UserRole_TakesPrecedenceOverDefault()
    var
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
    begin
        // [SCENARIO] User's explicit role takes precedence over the default role.
        Initialize();
        CreateRole('DEFAULT', true, Enum::"Bifrost LangModel Prov. ori"::None);
        CreateRole('USER-ROLE', false, Enum::"Bifrost LangModel Prov. ori"::Mock);
        SetupUserWithRole('USER-ROLE');
        MockProvider.SetIsConfigured(true);

        Assert.IsTrue(BifrostChatMgt.ShowBifrostChat(), 'User role should take precedence over default.');
        Assert.IsTrue(MockProvider.WasIsConfiguredCalled(), 'Mock should be invoked via user role.');
    end;

    [Test]
    procedure ContinueWithToolResults_RoleMock_DelegatesToMock()
    var
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ConversationState: Text;
        ToolResults: Text;
        ExpectedResponse: Text;
    begin
        // [SCENARIO] ContinueWithToolResults forwards state and results to the provider.
        Initialize();
        SetupUserWithRole('MOCK-ROLE');
        CreateRole('MOCK-ROLE', false, Enum::"Bifrost LangModel Prov. ori"::Mock);
        ConversationState := '{"internal":"state-blob"}';
        ToolResults := '[{"id":"call_1","name":"get_record","result":"{}","isError":false}]';
        ExpectedResponse := '{"type":"reply","reply":"Done."}';
        MockProvider.SetContinueResponse(ExpectedResponse);

        Assert.AreEqual(ExpectedResponse, BifrostChatMgt.ContinueWithToolResults(ConversationState, ToolResults), 'Should return mock continue response.');
        Assert.IsTrue(MockProvider.WasContinueWithToolResultsCalled(), 'ContinueWithToolResults should have been called.');
        Assert.AreEqual(ConversationState, MockProvider.GetLastConversationState(), 'Mock should receive conversation state.');
        Assert.AreEqual(ToolResults, MockProvider.GetLastToolResultsJson(), 'Mock should receive tool results.');
    end;

    [Test]
    procedure ContinueWithToolResults_NoneProvider_ReturnsErrorJson()
    var
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
        ResponseJson: JsonObject;
        ResponseToken: JsonToken;
    begin
        // [SCENARIO] None provider returns error JSON from ContinueWithToolResults.
        Initialize();
        DeleteCurrentUserSetup();
        CreateRole('DEFAULT', true, Enum::"Bifrost LangModel Prov. ori"::None);

        Assert.IsTrue(ResponseJson.ReadFrom(BifrostChatMgt.ContinueWithToolResults('{}', '[]')), 'Response should be valid JSON.');
        Assert.IsTrue(ResponseJson.Get('error', ResponseToken), 'Response should contain error field.');
    end;

    [Test]
    procedure BuildConfigJson_DebugMode_IncludesDebugTrue()
    var
        BifrostSetup: Record "Setup ori";
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ConfigJson: JsonObject;
        Token: JsonToken;
    begin
        // [SCENARIO] BuildConfigJson reflects debug mode from setup.
        Initialize();
        BifrostSetup.GetRecordOnce();
        BifrostSetup."Request Debug Mode" := true;
        BifrostSetup.Modify();

        SetupUserWithRole('MOCK-ROLE');
        CreateRole('MOCK-ROLE', false, Enum::"Bifrost LangModel Prov. ori"::Mock);
        MockProvider.SetConfigJson('{"model":"x"}');

        Assert.IsTrue(ConfigJson.ReadFrom(BifrostChatMgt.BuildConfigJson()), 'Should return valid JSON.');
        ConfigJson.Get('debug', Token);
        Assert.IsTrue(Token.AsValue().AsBoolean(), 'debug should be true when Request Debug Mode is on.');
    end;

    [Test]
    procedure BuildConfigJson_RoleWithSkill_IncludesContextSkill()
    var
        BifrostSetup: Record "Setup ori";
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ConfigJson: JsonObject;
        Token: JsonToken;
        SkillText: Text;
    begin
        // [SCENARIO] BuildConfigJson includes the role's skill blob as contextSkill
        Initialize();
        BifrostSetup.GetRecordOnce();
        BifrostSetup."Request Debug Mode" := false;
        BifrostSetup.Modify();

        SkillText := '# Test Skill' + '\n' + 'Use search_tables before guessing.';
        CreateRoleWithSkill('SKILL-ROLE', false, Enum::"Bifrost LangModel Prov. ori"::Mock, SkillText);
        SetupUserWithRole('SKILL-ROLE');
        MockProvider.SetConfigJson('{"model":"test"}');

        Assert.IsTrue(ConfigJson.ReadFrom(BifrostChatMgt.BuildConfigJson()), 'Should return valid JSON.');
        Assert.IsTrue(ConfigJson.Get('contextSkill', Token), 'Config should contain contextSkill.');
        Assert.AreEqual(SkillText, Token.AsValue().AsText(), 'contextSkill should match stored skill text.');
    end;

    [Test]
    procedure BuildConfigJson_RoleWithoutSkill_NoContextSkill()
    var
        BifrostSetup: Record "Setup ori";
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
        ConfigJson: JsonObject;
        Token: JsonToken;
    begin
        // [SCENARIO] BuildConfigJson omits contextSkill when role has no skill blob
        Initialize();
        BifrostSetup.GetRecordOnce();
        BifrostSetup."Request Debug Mode" := false;
        BifrostSetup.Modify();

        CreateRole('EMPTY-ROLE', false, Enum::"Bifrost LangModel Prov. ori"::Mock);
        SetupUserWithRole('EMPTY-ROLE');
        MockProvider.SetConfigJson('{"model":"test"}');

        Assert.IsTrue(ConfigJson.ReadFrom(BifrostChatMgt.BuildConfigJson()), 'Should return valid JSON.');
        Assert.IsFalse(ConfigJson.Get('contextSkill', Token), 'Config should not contain contextSkill when skill is empty.');
    end;

    [Test]
    procedure BuildConfigJson_NoUserSetup_NoContextSkill()
    var
        BifrostSetup: Record "Setup ori";
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
        ConfigJson: JsonObject;
        Token: JsonToken;
    begin
        // [SCENARIO] BuildConfigJson omits contextSkill when user has no setup record
        Initialize();
        BifrostSetup.GetRecordOnce();
        BifrostSetup."Request Debug Mode" := false;
        BifrostSetup.Modify();

        DeleteCurrentUserSetup();
        CreateRole('DEFAULT', true, Enum::"Bifrost LangModel Prov. ori"::None);

        Assert.IsTrue(ConfigJson.ReadFrom(BifrostChatMgt.BuildConfigJson()), 'Should return valid JSON.');
        Assert.IsFalse(ConfigJson.Get('contextSkill', Token), 'Config should not contain contextSkill without user setup.');
    end;

    [Test]
    procedure SendChatMessage_ArgumentFieldsPopulated()
    var
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
    begin
        // [SCENARIO] All argument fields reach the provider when SendChatMessage is called
        Initialize();
        CreateRoleWithConfig('CFG-ROLE', 'https://test.openai.azure.com', 'gpt-4o', '/openai/deployments/gpt-4o/chat/completions?api-version=2024', '/openai/models?api-version=2024', 120, 8192);
        SetupUserWithRole('CFG-ROLE');
        MockProvider.SetSendResponse('{"type":"reply","reply":"ok"}');

        BifrostChatMgt.SendChatMessage('{"messages":[]}');

        Assert.AreEqual('https://test.openai.azure.com', MockProvider.GetLastBaseUrl(), 'Base URL not passed.');
        Assert.AreEqual('gpt-4o', MockProvider.GetLastModel(), 'Model not passed.');
        Assert.AreEqual('/openai/deployments/gpt-4o/chat/completions?api-version=2024', MockProvider.GetLastChatPath(), 'Chat Path not passed.');
        Assert.AreEqual('/openai/models?api-version=2024', MockProvider.GetLastModelsPath(), 'Models Path not passed.');
        Assert.AreEqual(120000, MockProvider.GetLastTimeoutMs(), 'Timeout Ms not passed (should be seconds * 1000).');
        Assert.AreEqual(8192, MockProvider.GetLastMaxTokens(), 'Max Tokens not passed.');
    end;

    local procedure Initialize()
    var
        MockProvider: Codeunit "Mock Bifrost Chat Provider";
    begin
        MockProvider.Reset();
        DeleteAllRoles();
    end;

    local procedure SetupUserWithRole(RoleCode: Code[20])
    var
        BifrostUserSetup: Record "User Setup ori";
    begin
        if not BifrostUserSetup.Get(UserSecurityId()) then begin
            BifrostUserSetup.Init();
            BifrostUserSetup."User Security ID" := UserSecurityId();
            BifrostUserSetup.Insert(true);
        end;
        BifrostUserSetup."Bifrost Language Model Code" := RoleCode;
        BifrostUserSetup.Modify(true);
    end;

    local procedure CreateRole(RoleCode: Code[20]; IsDefault: Boolean; Provider: Enum "Bifrost LangModel Prov. ori")
    begin
        CreateRoleWithSkill(RoleCode, IsDefault, Provider, '');
    end;

    local procedure CreateRoleWithSkill(RoleCode: Code[20]; IsDefault: Boolean; Provider: Enum "Bifrost LangModel Prov. ori"; SkillText: Text)
    var
        BifrostLanguageModel: Record "Bifrost Language Model ori";
    begin
        if BifrostLanguageModel.Get(RoleCode) then
            BifrostLanguageModel.Delete(true);
        BifrostLanguageModel.Init();
        BifrostLanguageModel.Code := RoleCode;
        BifrostLanguageModel.Default := IsDefault;
        BifrostLanguageModel."Chat Provider" := Provider;
        if SkillText <> '' then
            BifrostLanguageModel.SetSkill(SkillText);
        BifrostLanguageModel.Insert(true);
    end;

    local procedure CreateRoleWithConfig(RoleCode: Code[20]; BaseUrl: Text; Model: Text; ChatPath: Text; ModelsPath: Text; TimeoutSec: Integer; MaxTokens: Integer)
    var
        BifrostLanguageModel: Record "Bifrost Language Model ori";
    begin
        if BifrostLanguageModel.Get(RoleCode) then
            BifrostLanguageModel.Delete(true);
        BifrostLanguageModel.Init();
        BifrostLanguageModel.Code := RoleCode;
        BifrostLanguageModel."Chat Provider" := Enum::"Bifrost LangModel Prov. ori"::Mock;
        BifrostLanguageModel."Base URL" := CopyStr(BaseUrl, 1, MaxStrLen(BifrostLanguageModel."Base URL"));
        BifrostLanguageModel.Model := CopyStr(Model, 1, MaxStrLen(BifrostLanguageModel.Model));
        BifrostLanguageModel."Chat Path" := CopyStr(ChatPath, 1, MaxStrLen(BifrostLanguageModel."Chat Path"));
        BifrostLanguageModel."Models Path" := CopyStr(ModelsPath, 1, MaxStrLen(BifrostLanguageModel."Models Path"));
        BifrostLanguageModel."Timeout Seconds" := TimeoutSec;
        BifrostLanguageModel."Max Tokens" := MaxTokens;
        BifrostLanguageModel.Insert(true);
    end;

    local procedure DeleteCurrentUserSetup()
    var
        BifrostUserSetup: Record "User Setup ori";
    begin
        if BifrostUserSetup.Get(UserSecurityId()) then
            BifrostUserSetup.Delete(true);
    end;

    local procedure DeleteAllRoles()
    var
        BifrostLanguageModel: Record "Bifrost Language Model ori";
    begin
        BifrostLanguageModel.DeleteAll(true);
    end;
}
