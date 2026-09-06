namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests for "LangModel Secrets ori", this app's facade over the Bifrost Foundation secret store:
/// secret code layout, registration of both codes with the right scope, the set/is-set/clear
/// round trip of the shared and the personal key, the personal-before-shared read order,
/// and the clean-up when a language model is deleted or renamed.
/// </summary>
codeunit 96009 "LangModel Secrets Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Any: Codeunit Any;
        IsInitialized: Boolean;
        TestCodeSequence: Integer;
        TestCodePrefixTok: Label 'X-SEC-', Locked = true;
        TestCodeFilterTok: Label 'X-SEC-*', Locked = true;

    local procedure Initialize()
    var
        LangModel: Record "Bifrost Language Model ori";
    begin
        LangModel.SetFilter(Code, TestCodeFilterTok);
        if not LangModel.IsEmpty() then
            LangModel.DeleteAll(true);

        if IsInitialized then
            exit;

        Any.SetDefaultSeed();
        IsInitialized := true;
    end;

    [Test]
    procedure GetSecretCodes_BuildBothCodesFromLanguageModelCode()
    var
        LangModelSecrets: Codeunit "LangModel Secrets ori";
    begin
        // [SCENARIO] The two secret codes of a language model follow the documented layout.
        Initialize();

        // [GIVEN] A language model code
        // [WHEN] The secret codes are built
        // [THEN] They carry the LANGMODEL- prefix and the documented suffixes
        Assert.AreEqual('LANGMODEL-COPILOT-API-KEY', LangModelSecrets.GetServiceKeyCode('COPILOT'), 'Unexpected shared key code.');
        Assert.AreEqual('LANGMODEL-COPILOT-USER-API-KEY', LangModelSecrets.GetUserKeyCode('COPILOT'), 'Unexpected personal key code.');
    end;

    [Test]
    procedure GetSecretCodes_LongestLanguageModelCode_FitsInCode50()
    var
        LangModelSecrets: Codeunit "LangModel Secrets ori";
        LongCode: Code[20];
    begin
        // [SCENARIO] A language model code of the maximum length never has to be truncated.
        Initialize();

        // [GIVEN] A language model code that fills Code[20]
        LongCode := 'ABCDEFGHIJKLMNOPQRST';

        // [WHEN/THEN] Both secret codes stay within Code[50] and keep the full model code
        Assert.AreEqual('LANGMODEL-' + LongCode + '-API-KEY', LangModelSecrets.GetServiceKeyCode(LongCode), 'Shared key code must not be truncated.');
        Assert.AreEqual('LANGMODEL-' + LongCode + '-USER-API-KEY', LangModelSecrets.GetUserKeyCode(LongCode), 'Personal key code must not be truncated.');
    end;

    [Test]
    procedure GetSecretCodes_BlankLanguageModelCode_ReturnsBlank()
    var
        LangModelSecrets: Codeunit "LangModel Secrets ori";
    begin
        // [SCENARIO] A blank language model code produces no secret code.
        Initialize();

        // [WHEN/THEN]
        Assert.AreEqual('', LangModelSecrets.GetServiceKeyCode(''), 'A blank model code must produce no shared key code.');
        Assert.AreEqual('', LangModelSecrets.GetUserKeyCode(''), 'A blank model code must produce no personal key code.');
    end;

    [Test]
    procedure Insert_LanguageModel_RegistersBothSecretsWithCorrectScope()
    var
        LangModel: Record "Bifrost Language Model ori";
        ServiceSecret: Record "App Secret ori";
        UserSecret: Record "App Secret ori";
        LangModelSecrets: Codeunit "LangModel Secrets ori";
    begin
        // [SCENARIO] Inserting a language model registers both API key secrets.
        Initialize();

        // [GIVEN] A new language model
        CreateLanguageModel(LangModel);

        // [WHEN] The registry is read back
        // [THEN] The shared key is registered with company scope
        Assert.IsTrue(ServiceSecret.Get(LangModelSecrets.GetAppId(), LangModelSecrets.GetServiceKeyCode(LangModel.Code)), 'The shared key must be registered on insert.');
        Assert.AreEqual(ServiceSecret.Scope::Company.AsInteger(), ServiceSecret.Scope.AsInteger(), 'The shared key must have company scope.');
        Assert.AreNotEqual('', ServiceSecret.Description, 'The shared key must have a description.');

        // [THEN] The personal key is registered with company and user scope
        Assert.IsTrue(UserSecret.Get(LangModelSecrets.GetAppId(), LangModelSecrets.GetUserKeyCode(LangModel.Code)), 'The personal key must be registered on insert.');
        Assert.AreEqual(UserSecret.Scope::"Company And User".AsInteger(), UserSecret.Scope.AsInteger(), 'The personal key must have company and user scope.');
        Assert.AreNotEqual('', UserSecret.Description, 'The personal key must have a description.');
    end;

    [Test]
    procedure Register_CalledTwice_IsIdempotent()
    var
        LangModel: Record "Bifrost Language Model ori";
        AppSecret: Record "App Secret ori";
        LangModelSecrets: Codeunit "LangModel Secrets ori";
        CountBefore: Integer;
    begin
        // [SCENARIO] Register can be called again from install or upgrade without creating duplicates.
        Initialize();

        // [GIVEN] A registered language model
        CreateLanguageModel(LangModel);
        AppSecret.SetRange("App Id", LangModelSecrets.GetAppId());
        CountBefore := AppSecret.Count();

        // [WHEN] Register is called again
        LangModelSecrets.Register(LangModel.Code);
        LangModelSecrets.RegisterAll();

        // [THEN] No extra registry rows appear
        Assert.AreEqual(CountBefore, AppSecret.Count(), 'Register must be idempotent.');
    end;

    [Test]
    procedure ServiceKey_SetIsSetClear_RoundTrips()
    var
        LangModel: Record "Bifrost Language Model ori";
        LangModelSecrets: Codeunit "LangModel Secrets ori";
        ApiKey: SecretText;
    begin
        // [SCENARIO] The shared API key can be stored, detected and removed.
        Initialize();

        // [GIVEN] A language model with no shared key
        CreateLanguageModel(LangModel);
        Assert.IsFalse(LangModelSecrets.HasServiceKey(LangModel.Code), 'A new language model must have no shared key.');

        // [WHEN] A shared key is stored
        LangModelSecrets.SetServiceKey(LangModel.Code, AsSecret('sk-shared-' + Format(Any.IntegerInRange(1000, 9999))));

        // [THEN] It is reported as set and can be read back
        Assert.IsTrue(LangModelSecrets.HasServiceKey(LangModel.Code), 'The shared key must be reported as set.');
        Assert.IsTrue(LangModelSecrets.TryGetApiKey(LangModel.Code, ApiKey), 'The shared key must be readable.');
        Assert.IsFalse(ApiKey.IsEmpty(), 'The shared key value must not be empty.');

        // [WHEN] The shared key is cleared
        LangModelSecrets.ClearServiceKey(LangModel.Code);

        // [THEN] It is gone
        Assert.IsFalse(LangModelSecrets.HasServiceKey(LangModel.Code), 'The shared key must be gone after Clear.');
        Assert.IsFalse(LangModelSecrets.TryGetApiKey(LangModel.Code, ApiKey), 'No key must be readable after Clear.');
    end;

    [Test]
    procedure UserKey_SetIsSetClear_RoundTrips()
    var
        LangModel: Record "Bifrost Language Model ori";
        LangModelSecrets: Codeunit "LangModel Secrets ori";
        ApiKey: SecretText;
    begin
        // [SCENARIO] The personal API key can be stored, detected and removed.
        Initialize();

        // [GIVEN] A language model with no personal key
        CreateLanguageModel(LangModel);
        Assert.IsFalse(LangModelSecrets.HasUserKey(LangModel.Code), 'A new language model must have no personal key.');

        // [WHEN] A personal key is stored
        LangModelSecrets.SetUserKey(LangModel.Code, AsSecret('sk-personal-' + Format(Any.IntegerInRange(1000, 9999))));

        // [THEN] It is reported as set and can be read back
        Assert.IsTrue(LangModelSecrets.HasUserKey(LangModel.Code), 'The personal key must be reported as set.');
        Assert.IsTrue(LangModelSecrets.TryGetApiKey(LangModel.Code, ApiKey), 'The personal key must be readable.');
        Assert.IsFalse(ApiKey.IsEmpty(), 'The personal key value must not be empty.');

        // [WHEN] The personal key is cleared
        LangModelSecrets.ClearUserKey(LangModel.Code);

        // [THEN] It is gone
        Assert.IsFalse(LangModelSecrets.HasUserKey(LangModel.Code), 'The personal key must be gone after Clear.');
        Assert.IsFalse(LangModelSecrets.TryGetApiKey(LangModel.Code, ApiKey), 'No key must be readable after Clear.');
    end;

    [Test]
    procedure ServiceAndUserKey_AreStoredIndependently()
    var
        LangModel: Record "Bifrost Language Model ori";
        LangModelSecrets: Codeunit "LangModel Secrets ori";
    begin
        // [SCENARIO] Clearing the personal key leaves the shared key in place.
        Initialize();

        // [GIVEN] A language model with both keys stored
        CreateLanguageModel(LangModel);
        LangModelSecrets.SetServiceKey(LangModel.Code, AsSecret('sk-shared'));
        LangModelSecrets.SetUserKey(LangModel.Code, AsSecret('sk-personal'));

        // [WHEN] Only the personal key is cleared
        LangModelSecrets.ClearUserKey(LangModel.Code);

        // [THEN] The shared key survives
        Assert.IsFalse(LangModelSecrets.HasUserKey(LangModel.Code), 'The personal key must be gone.');
        Assert.IsTrue(LangModelSecrets.HasServiceKey(LangModel.Code), 'The shared key must survive clearing the personal key.');
    end;

    [Test]
    procedure TryGetApiKey_PersonalKeyTakesPriorityOverSharedKey()
    var
        LangModel: Record "Bifrost Language Model ori";
        ServiceSecret: Record "App Secret ori";
        UserSecret: Record "App Secret ori";
        LangModelSecrets: Codeunit "LangModel Secrets ori";
        ApiKey: SecretText;
    begin
        // [SCENARIO] When both keys exist, the personal key is the one a chat request uses.
        Initialize();

        // [GIVEN] A language model with a shared and a personal key
        CreateLanguageModel(LangModel);
        LangModelSecrets.SetServiceKey(LangModel.Code, AsSecret('sk-shared'));
        LangModelSecrets.SetUserKey(LangModel.Code, AsSecret('sk-personal'));

        // [WHEN] The API key for a request is resolved
        Assert.IsTrue(LangModelSecrets.TryGetApiKey(LangModel.Code, ApiKey), 'A key must be found.');

        // [THEN] Only the personal key was read
        UserSecret.Get(LangModelSecrets.GetAppId(), LangModelSecrets.GetUserKeyCode(LangModel.Code));
        ServiceSecret.Get(LangModelSecrets.GetAppId(), LangModelSecrets.GetServiceKeyCode(LangModel.Code));
        Assert.AreNotEqual(0DT, UserSecret."Last Used On", 'The personal key must be the key that was read.');
        Assert.AreEqual(0DT, ServiceSecret."Last Used On", 'The shared key must not be read while a personal key exists.');
    end;

    [Test]
    procedure TryGetApiKey_WithoutPersonalKey_FallsBackToSharedKey()
    var
        LangModel: Record "Bifrost Language Model ori";
        ServiceSecret: Record "App Secret ori";
        LangModelSecrets: Codeunit "LangModel Secrets ori";
        ApiKey: SecretText;
    begin
        // [SCENARIO] Without a personal key, a chat request uses the shared key.
        Initialize();

        // [GIVEN] A language model with only a shared key
        CreateLanguageModel(LangModel);
        LangModelSecrets.SetServiceKey(LangModel.Code, AsSecret('sk-shared'));

        // [WHEN] The API key for a request is resolved
        Assert.IsTrue(LangModelSecrets.TryGetApiKey(LangModel.Code, ApiKey), 'The shared key must be used as the fallback.');

        // [THEN] The shared key was read
        ServiceSecret.Get(LangModelSecrets.GetAppId(), LangModelSecrets.GetServiceKeyCode(LangModel.Code));
        Assert.AreNotEqual(0DT, ServiceSecret."Last Used On", 'The shared key must be the key that was read.');
    end;

    [Test]
    procedure TryGetApiKey_NoKeyStored_ReturnsFalse()
    var
        LangModel: Record "Bifrost Language Model ori";
        LangModelSecrets: Codeunit "LangModel Secrets ori";
        ApiKey: SecretText;
    begin
        // [SCENARIO] A language model without any key reports no key.
        Initialize();

        // [GIVEN] A language model with no key at all
        CreateLanguageModel(LangModel);

        // [WHEN/THEN]
        Assert.IsFalse(LangModelSecrets.TryGetApiKey(LangModel.Code, ApiKey), 'No key must be found.');
        Assert.IsTrue(ApiKey.IsEmpty(), 'The returned value must stay empty.');
    end;

    [Test]
    procedure TryGetApiKey_BlankLanguageModelCode_ReturnsFalse()
    var
        LangModelSecrets: Codeunit "LangModel Secrets ori";
        ApiKey: SecretText;
    begin
        // [SCENARIO] Reading a key for a blank language model code fails safely.
        Initialize();

        // [WHEN/THEN]
        Assert.IsFalse(LangModelSecrets.TryGetApiKey('', ApiKey), 'A blank model code must not resolve a key.');
    end;

    [Test]
    procedure SetServiceKey_BlankLanguageModelCode_Errors()
    var
        LangModelSecrets: Codeunit "LangModel Secrets ori";
    begin
        // [SCENARIO] Storing a key without a language model is rejected with a helpful message.
        Initialize();

        // [WHEN] A key is stored for a blank language model code
        asserterror LangModelSecrets.SetServiceKey('', AsSecret('sk-shared'));

        // [THEN] The call fails
        Assert.ExpectedError('A language model code must be specified');
    end;

    [Test]
    procedure Delete_LanguageModel_ClearsBothSecrets()
    var
        LangModel: Record "Bifrost Language Model ori";
        LangModelSecrets: Codeunit "LangModel Secrets ori";
        ModelCode: Code[20];
    begin
        // [SCENARIO] Deleting a language model removes both of its stored API keys.
        Initialize();

        // [GIVEN] A language model with a shared and a personal key
        CreateLanguageModel(LangModel);
        ModelCode := LangModel.Code;
        LangModelSecrets.SetServiceKey(ModelCode, AsSecret('sk-shared'));
        LangModelSecrets.SetUserKey(ModelCode, AsSecret('sk-personal'));
        Assert.IsTrue(LangModelSecrets.HasServiceKey(ModelCode), 'The shared key must be stored before the delete.');
        Assert.IsTrue(LangModelSecrets.HasUserKey(ModelCode), 'The personal key must be stored before the delete.');

        // [WHEN] The language model is deleted
        LangModel.Delete(true);

        // [THEN] Both stored values are gone
        Assert.IsFalse(LangModelSecrets.HasServiceKey(ModelCode), 'The shared key must be cleared on delete.');
        Assert.IsFalse(LangModelSecrets.HasUserKey(ModelCode), 'The personal key must be cleared on delete.');
    end;

    [Test]
    procedure Rename_LanguageModel_MovesSecretsToTheNewCode()
    var
        LangModel: Record "Bifrost Language Model ori";
        LangModelSecrets: Codeunit "LangModel Secrets ori";
        OldCode: Code[20];
        NewCode: Code[20];
    begin
        // [SCENARIO] Renaming a language model carries its keys over to the new code.
        Initialize();

        // [GIVEN] A language model with a shared key
        CreateLanguageModel(LangModel);
        OldCode := LangModel.Code;
        LangModelSecrets.SetServiceKey(OldCode, AsSecret('sk-shared'));

        // [WHEN] The language model is renamed
        NewCode := UnusedLanguageModelCode();
        LangModel.Rename(NewCode);

        // [THEN] The key is stored under the new code and gone from the old one
        Assert.IsTrue(LangModelSecrets.HasServiceKey(NewCode), 'The shared key must be available under the new code.');
        Assert.IsFalse(LangModelSecrets.HasServiceKey(OldCode), 'The shared key must be gone from the old code.');
    end;

    local procedure CreateLanguageModel(var LangModel: Record "Bifrost Language Model ori")
    begin
        LangModel.Init();
        LangModel.Code := UnusedLanguageModelCode();
        LangModel.Description := 'Bifrost Language Models secret store test';
        LangModel.Insert(true);
    end;

    local procedure UnusedLanguageModelCode() NewCode: Code[20]
    var
        LangModel: Record "Bifrost Language Model ori";
        AppSecret: Record "App Secret ori";
        LangModelSecrets: Codeunit "LangModel Secrets ori";
    begin
        // A code is only free when no language model uses it AND the secret store holds no
        // registry row for it. Registrations outlive the model - Clear keeps the row so the
        // administrator still sees the missing secret - so a recycled code would inherit the
        // Set On and Last Used On stamps of an earlier test.
        repeat
            TestCodeSequence += 1;
            NewCode := CopyStr(TestCodePrefixTok + Format(TestCodeSequence) + '-' + Format(Any.IntegerInRange(100000, 999999)), 1, MaxStrLen(NewCode));
        until (not LangModel.Get(NewCode)) and (not AppSecret.Get(LangModelSecrets.GetAppId(), LangModelSecrets.GetServiceKeyCode(NewCode)));
    end;

    local procedure AsSecret(Value: Text) Secret: SecretText
    begin
        Secret := Value;
    end;
}
