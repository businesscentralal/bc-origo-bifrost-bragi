namespace Origo.Bifrost.LanguageModels.Test;
using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;

using System.TestLibraries.Utilities;

/// <summary>
/// Tests for the six migrated chat provider codeunits (OpenAI, Azure OpenAI, Custom LLM,
/// Anthropic, xAI, Google/Gemini): metadata dispatch, default configuration, IsConfigured,
/// and the "no API key" error path on TestConnection. None of these make a live HTTP call.
/// </summary>
codeunit 96012 "LangModel Providers Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure OpenAI_Metadata()
    var
        Provider: Interface "Bifrost LangModel Provider ori";
    begin
        Provider := Enum::"Bifrost LangModel Prov. ori"::OpenAI;
        VerifyCommonMetadata(Provider, 'OpenAI', true);
        VerifyNoKeyBlocksConnection(Provider);
    end;

    [Test]
    procedure AzureOpenAI_Metadata()
    var
        Provider: Interface "Bifrost LangModel Provider ori";
    begin
        Provider := Enum::"Bifrost LangModel Prov. ori"::"Azure OpenAI";
        VerifyCommonMetadata(Provider, 'Azure OpenAI', true);
        VerifyNoKeyBlocksConnection(Provider);
    end;

    [Test]
    procedure CustomLLM_Metadata()
    var
        Provider: Interface "Bifrost LangModel Provider ori";
    begin
        Provider := Enum::"Bifrost LangModel Prov. ori"::"Custom LLM";
        VerifyCommonMetadata(Provider, 'Custom LLM', true);
    end;

    [Test]
    procedure Anthropic_Metadata()
    var
        TempArg: Record "Bifrost Chat Argument ori" temporary;
        Provider: Interface "Bifrost LangModel Provider ori";
    begin
        Provider := Enum::"Bifrost LangModel Prov. ori"::Anthropic;
        VerifyCommonMetadata(Provider, 'Anthropic', true);
        VerifyNoKeyBlocksConnection(Provider);

        // Anthropic ships default base URL/model — IsConfigured should be true with only a key
        TempArg.Init();
        TempArg.SetApiKey(AsSecret('sk-ant-test'));
        TempArg."Procedure Type" := TempArg."Procedure Type"::IsConfigured;
        Provider.Execute(TempArg);
        Assert.IsTrue(TempArg."Result Boolean", 'Anthropic should be configured from key + default base URL.');
    end;

    [Test]
    procedure xAI_Metadata()
    var
        Provider: Interface "Bifrost LangModel Provider ori";
    begin
        Provider := Enum::"Bifrost LangModel Prov. ori"::"xAI";
        VerifyCommonMetadata(Provider, 'xAI', true);
        VerifyNoKeyBlocksConnection(Provider);
    end;

    [Test]
    procedure Gemini_Metadata()
    var
        Provider: Interface "Bifrost LangModel Provider ori";
    begin
        Provider := Enum::"Bifrost LangModel Prov. ori"::Google;
        VerifyCommonMetadata(Provider, 'Google', true);
        VerifyNoKeyBlocksConnection(Provider);
    end;

    [Test]
    procedure IsConfigured_WithoutApiKey_ReturnsFalse_ForEveryExternalProvider()
    var
        TempArg: Record "Bifrost Chat Argument ori" temporary;
        Provider: Interface "Bifrost LangModel Provider ori";
    begin
        Provider := Enum::"Bifrost LangModel Prov. ori"::OpenAI;
        TempArg.Init();
        TempArg."Procedure Type" := TempArg."Procedure Type"::IsConfigured;
        Provider.Execute(TempArg);
        Assert.IsFalse(TempArg."Result Boolean", 'OpenAI without a key should not be configured.');

        Provider := Enum::"Bifrost LangModel Prov. ori"::"Custom LLM";
        Clear(TempArg);
        TempArg."Procedure Type" := TempArg."Procedure Type"::IsConfigured;
        Provider.Execute(TempArg);
        Assert.IsFalse(TempArg."Result Boolean", 'Custom LLM without a key should not be configured.');
    end;

    local procedure VerifyCommonMetadata(var Provider: Interface "Bifrost LangModel Provider ori"; ExpectedName: Text; ExpectRequiresApiKey: Boolean)
    var
        TempArg: Record "Bifrost Chat Argument ori" temporary;
    begin
        TempArg.Init();
        TempArg."Procedure Type" := TempArg."Procedure Type"::GetProviderName;
        Provider.Execute(TempArg);
        Assert.AreEqual(ExpectedName, TempArg.GetResultText(), 'Unexpected provider name.');

        Clear(TempArg);
        TempArg."Procedure Type" := TempArg."Procedure Type"::RequiresApiKey;
        Provider.Execute(TempArg);
        Assert.AreEqual(ExpectRequiresApiKey, TempArg."Result Boolean", 'Unexpected RequiresApiKey.');

        Clear(TempArg);
        TempArg."Procedure Type" := TempArg."Procedure Type"::HasExternalEndpoint;
        Provider.Execute(TempArg);
        Assert.IsTrue(TempArg."Result Boolean", 'Every migrated provider has an external endpoint.');

        Clear(TempArg);
        TempArg."Procedure Type" := TempArg."Procedure Type"::SupportsToolCalling;
        Provider.Execute(TempArg);
        Assert.IsTrue(TempArg."Result Boolean", 'Every migrated provider supports tool calling.');

        Clear(TempArg);
        TempArg."Procedure Type" := TempArg."Procedure Type"::GetDefaultTimeoutSeconds;
        Provider.Execute(TempArg);
        Assert.IsTrue(TempArg."Result Integer" > 0, 'Default timeout should be positive.');

        Clear(TempArg);
        TempArg."Procedure Type" := TempArg."Procedure Type"::GetDefaultMaxTokens;
        Provider.Execute(TempArg);
        Assert.IsTrue(TempArg."Result Integer" > 0, 'Default max tokens should be positive.');
    end;

    local procedure VerifyNoKeyBlocksConnection(var Provider: Interface "Bifrost LangModel Provider ori")
    var
        TempArg: Record "Bifrost Chat Argument ori" temporary;
    begin
        TempArg.Init();
        TempArg."Procedure Type" := TempArg."Procedure Type"::TestConnection;
        Provider.Execute(TempArg);
        Assert.IsFalse(TempArg."Result Boolean", 'TestConnection without a key should fail.');
        Assert.AreNotEqual('', TempArg.GetErrorMessage(), 'TestConnection without a key should set an error message.');
    end;

    local procedure AsSecret(Value: Text) Secret: SecretText
    begin
        Secret := Value;
    end;
}
