namespace Origo.Bifrost.LanguageModels;

using Origo.Bifrost;

/// <summary>
/// This app's facade over the Bifrost Foundation secret store (codeunit "Secret Store ori").
/// Every API key of a language model is stored by Foundation under this app's id with the
/// secret codes LANGMODEL-&lt;Code&gt;-API-KEY (shared, company scope) and
/// LANGMODEL-&lt;Code&gt;-USER-API-KEY (personal, company and user scope).
/// Bifrost Language Models never writes to IsolatedStorage itself and never keeps a key in a table,
/// in telemetry or in an error message.
/// </summary>
codeunit 10035422 "LangModel Secrets ori"
{
    Access = Public;

    var
        CodePrefixTok: Label 'LANGMODEL-', Locked = true;
        ServiceCodeSuffixTok: Label '-API-KEY', Locked = true;
        UserCodeSuffixTok: Label '-USER-API-KEY', Locked = true;
        ServiceKeyDescTok: Label 'Shared API key for language model %1.', Comment = '%1 = language model code, is-IS=Sameiginlegur API-lykill fyrir mállíkanið %1.';
        UserKeyDescTok: Label 'Personal API key for language model %1.', Comment = '%1 = language model code, is-IS=Persónulegur API-lykill fyrir mállíkanið %1.';
        NoServiceKeyPermissionErr: Label 'You need the BIFROST ChatSvc ori permission set to manage the shared API key of a language model.', Comment = 'is-IS=Þú þarft heimildasafnið BIFROST ChatSvc ori til að stjórna sameiginlegum API-lykli mállíkans.';
        LanguageModelCodeMissingErr: Label 'A language model code must be specified before an API key can be stored.', Comment = 'is-IS=Tilgreina verður kóða mállíkans áður en hægt er að geyma API-lykil.';

    /// <summary>
    /// Returns the application id of Bifrost Language Models, used as the owner of every secret.
    /// </summary>
    /// <returns>Guid. The current module id.</returns>
    procedure GetAppId(): Guid
    var
        AppInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(AppInfo);
        exit(AppInfo.Id());
    end;

    /// <summary>
    /// Builds the secret code of the shared (service) API key of a language model.
    /// The longest possible result is 43 characters (10 + Code[20] + 8), so a language model
    /// code never has to be truncated to fit the Code[50] secret code.
    /// </summary>
    /// <param name="LangModelCode">The code of the language model.</param>
    /// <returns>Code[50]. LANGMODEL-&lt;Code&gt;-API-KEY, or blank when the language model code is blank.</returns>
    procedure GetServiceKeyCode(LangModelCode: Code[20]): Code[50]
    begin
        if LangModelCode = '' then
            exit('');
        exit(CopyStr(CodePrefixTok + UpperCase(LangModelCode) + ServiceCodeSuffixTok, 1, 50));
    end;

    /// <summary>
    /// Builds the secret code of the personal (per user) API key of a language model.
    /// The longest possible result is 43 characters (10 + Code[20] + 13), so a language model
    /// code never has to be truncated to fit the Code[50] secret code.
    /// </summary>
    /// <param name="LangModelCode">The code of the language model.</param>
    /// <returns>Code[50]. LANGMODEL-&lt;Code&gt;-USER-API-KEY, or blank when the language model code is blank.</returns>
    procedure GetUserKeyCode(LangModelCode: Code[20]): Code[50]
    begin
        if LangModelCode = '' then
            exit('');
        exit(CopyStr(CodePrefixTok + UpperCase(LangModelCode) + UserCodeSuffixTok, 1, 50));
    end;

    /// <summary>
    /// Registers both API key secrets of a language model with the Bifrost Foundation secret store.
    /// Idempotent - safe to call on insert, from the install codeunit and from the upgrade codeunit.
    /// </summary>
    /// <param name="LangModelCode">The code of the language model.</param>
    procedure Register(LangModelCode: Code[20])
    var
        SecretStore: Codeunit "Secret Store ori";
    begin
        if LangModelCode = '' then
            exit;
        SecretStore.Register(GetAppId(), GetServiceKeyCode(LangModelCode), BuildDescription(ServiceKeyDescTok, LangModelCode), Enum::"Secret Scope ori"::Company);
        SecretStore.Register(GetAppId(), GetUserKeyCode(LangModelCode), BuildDescription(UserKeyDescTok, LangModelCode), Enum::"Secret Scope ori"::"Company And User");
    end;

    /// <summary>
    /// Registers the API key secrets of every language model that exists in this company.
    /// Called from the install and the upgrade codeunit so that an administrator sees the
    /// missing keys on the Bifrost App Secrets page right after deployment.
    /// </summary>
    procedure RegisterAll()
    var
        LangModel: Record "Bifrost Language Model ori";
    begin
        LangModel.SetLoadFields(Code);
        if not LangModel.FindSet() then
            exit;
        repeat
            Register(LangModel.Code);
        until LangModel.Next() = 0;
    end;

    /// <summary>
    /// Removes the stored values of both API key secrets of a language model.
    /// The registrations themselves stay, so the administrator keeps seeing which key is missing.
    /// </summary>
    /// <param name="LangModelCode">The code of the language model.</param>
    procedure ClearSecrets(LangModelCode: Code[20])
    var
        SecretStore: Codeunit "Secret Store ori";
    begin
        if LangModelCode = '' then
            exit;
        SecretStore.Clear(GetAppId(), GetServiceKeyCode(LangModelCode));
        SecretStore.Clear(GetAppId(), GetUserKeyCode(LangModelCode));
    end;

    /// <summary>
    /// Registers the secrets of the new code, carries over the values this user can read and
    /// clears the values of the old code. Called when a language model is renamed.
    /// Personal keys of other users cannot be read from this session and are not carried over -
    /// those users enter their key again on the language model card.
    /// </summary>
    /// <param name="OldLangModelCode">The code the language model had before the rename.</param>
    /// <param name="NewLangModelCode">The code the language model has after the rename.</param>
    [NonDebuggable]
    procedure MoveSecrets(OldLangModelCode: Code[20]; NewLangModelCode: Code[20])
    var
        SecretStore: Codeunit "Secret Store ori";
        Value: SecretText;
    begin
        if (OldLangModelCode = '') or (NewLangModelCode = '') then
            exit;
        if OldLangModelCode = NewLangModelCode then
            exit;

        Register(NewLangModelCode);

        if SecretStore.TryGet(GetAppId(), GetServiceKeyCode(OldLangModelCode), Value) then
            if not Value.IsEmpty() then
                SecretStore.Set(GetAppId(), GetServiceKeyCode(NewLangModelCode), Value);

        if SecretStore.TryGet(GetAppId(), GetUserKeyCode(OldLangModelCode), Value) then
            if not Value.IsEmpty() then
                SecretStore.Set(GetAppId(), GetUserKeyCode(NewLangModelCode), Value);

        ClearSecrets(OldLangModelCode);
    end;

    /// <summary>
    /// Returns whether a shared (service) API key is stored for a language model.
    /// </summary>
    /// <param name="LangModelCode">The code of the language model.</param>
    /// <returns>Boolean. True when a value is stored.</returns>
    procedure HasServiceKey(LangModelCode: Code[20]): Boolean
    var
        SecretStore: Codeunit "Secret Store ori";
    begin
        if LangModelCode = '' then
            exit(false);
        exit(SecretStore.IsSet(GetAppId(), GetServiceKeyCode(LangModelCode)));
    end;

    /// <summary>
    /// Returns whether the current user has a personal API key stored for a language model.
    /// </summary>
    /// <param name="LangModelCode">The code of the language model.</param>
    /// <returns>Boolean. True when a value is stored for this user.</returns>
    procedure HasUserKey(LangModelCode: Code[20]): Boolean
    var
        SecretStore: Codeunit "Secret Store ori";
    begin
        if LangModelCode = '' then
            exit(false);
        exit(SecretStore.IsSet(GetAppId(), GetUserKeyCode(LangModelCode)));
    end;

    /// <summary>
    /// Returns whether the current user holds the permission set that governs the shared API key.
    /// </summary>
    /// <returns>Boolean. True when the user may set or clear the shared key.</returns>
    procedure HasServiceKeyPermission(): Boolean
    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
    begin
        exit(ProviderBase.HasServiceKeyPermission());
    end;

    /// <summary>
    /// Opens the shared Bifrost masked-input dialog and stores the entered value as the
    /// shared (service) API key of a language model.
    /// </summary>
    /// <param name="LangModelCode">The code of the language model.</param>
    /// <returns>Boolean. True when a value was entered and stored.</returns>
    [NonDebuggable]
    procedure SetServiceKeyFromDialog(LangModelCode: Code[20]): Boolean
    var
        SecretStore: Codeunit "Secret Store ori";
    begin
        CheckLangModelCode(LangModelCode);
        CheckServiceKeyPermission();
        Register(LangModelCode);
        exit(SecretStore.SetFromDialog(GetAppId(), GetServiceKeyCode(LangModelCode)));
    end;

    /// <summary>
    /// Opens the shared Bifrost masked-input dialog and stores the entered value as the
    /// current user's personal API key for a language model.
    /// </summary>
    /// <param name="LangModelCode">The code of the language model.</param>
    /// <returns>Boolean. True when a value was entered and stored.</returns>
    [NonDebuggable]
    procedure SetUserKeyFromDialog(LangModelCode: Code[20]): Boolean
    var
        SecretStore: Codeunit "Secret Store ori";
    begin
        CheckLangModelCode(LangModelCode);
        Register(LangModelCode);
        exit(SecretStore.SetFromDialog(GetAppId(), GetUserKeyCode(LangModelCode)));
    end;

    /// <summary>
    /// Stores the shared (service) API key of a language model without a dialog.
    /// Used by the chat control add-in and by tests.
    /// </summary>
    /// <param name="LangModelCode">The code of the language model.</param>
    /// <param name="Value">The API key. Never logged, never stored in a table.</param>
    [NonDebuggable]
    procedure SetServiceKey(LangModelCode: Code[20]; Value: SecretText)
    var
        SecretStore: Codeunit "Secret Store ori";
    begin
        CheckLangModelCode(LangModelCode);
        CheckServiceKeyPermission();
        Register(LangModelCode);
        SecretStore.Set(GetAppId(), GetServiceKeyCode(LangModelCode), Value);
    end;

    /// <summary>
    /// Stores the current user's personal API key for a language model without a dialog.
    /// Used by the chat control add-in and by tests.
    /// </summary>
    /// <param name="LangModelCode">The code of the language model.</param>
    /// <param name="Value">The API key. Never logged, never stored in a table.</param>
    [NonDebuggable]
    procedure SetUserKey(LangModelCode: Code[20]; Value: SecretText)
    var
        SecretStore: Codeunit "Secret Store ori";
    begin
        CheckLangModelCode(LangModelCode);
        Register(LangModelCode);
        SecretStore.Set(GetAppId(), GetUserKeyCode(LangModelCode), Value);
    end;

    /// <summary>
    /// Removes the stored shared (service) API key of a language model.
    /// </summary>
    /// <param name="LangModelCode">The code of the language model.</param>
    procedure ClearServiceKey(LangModelCode: Code[20])
    var
        SecretStore: Codeunit "Secret Store ori";
    begin
        if LangModelCode = '' then
            exit;
        CheckServiceKeyPermission();
        SecretStore.Clear(GetAppId(), GetServiceKeyCode(LangModelCode));
    end;

    /// <summary>
    /// Removes the current user's personal API key for a language model.
    /// </summary>
    /// <param name="LangModelCode">The code of the language model.</param>
    procedure ClearUserKey(LangModelCode: Code[20])
    var
        SecretStore: Codeunit "Secret Store ori";
    begin
        if LangModelCode = '' then
            exit;
        SecretStore.Clear(GetAppId(), GetUserKeyCode(LangModelCode));
    end;

    /// <summary>
    /// Reads the API key a chat request must use for a language model: the current user's
    /// personal key when one is stored, otherwise the shared key.
    /// Stamps the registry row of the key that was used.
    /// </summary>
    /// <param name="LangModelCode">The code of the language model.</param>
    /// <param name="Value">Receives the API key when one is stored.</param>
    /// <returns>Boolean. True when a non-empty key was found.</returns>
    [NonDebuggable]
    procedure TryGetApiKey(LangModelCode: Code[20]; var Value: SecretText): Boolean
    var
        SecretStore: Codeunit "Secret Store ori";
        EmptyValue: Text;
    begin
        Value := EmptyValue;
        if LangModelCode = '' then
            exit(false);

        if SecretStore.TryGet(GetAppId(), GetUserKeyCode(LangModelCode), Value) then
            if not Value.IsEmpty() then begin
                SecretStore.MarkUsed(GetAppId(), GetUserKeyCode(LangModelCode));
                exit(true);
            end;

        if SecretStore.TryGet(GetAppId(), GetServiceKeyCode(LangModelCode), Value) then
            if not Value.IsEmpty() then begin
                SecretStore.MarkUsed(GetAppId(), GetServiceKeyCode(LangModelCode));
                exit(true);
            end;

        Value := EmptyValue;
        exit(false);
    end;

    /// <summary>
    /// Counts the language models that need an API key but have neither a shared key nor a
    /// personal key stored for the current user.
    /// </summary>
    /// <returns>Integer. The number of language models without a usable API key.</returns>
    procedure CountModelsWithoutKey(): Integer
    var
        LangModel: Record "Bifrost Language Model ori";
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        Provider: Interface "Bifrost LangModel Provider ori";
        MissingCount: Integer;
    begin
        LangModel.SetLoadFields(Code, "Chat Provider");
        if not LangModel.FindSet() then
            exit(0);
        repeat
            Provider := LangModel."Chat Provider";
            TempArgument.Init();
            TempArgument."Procedure Type" := TempArgument."Procedure Type"::RequiresApiKey;
            TempArgument."Result Boolean" := false;
            Provider.Execute(TempArgument);
            if TempArgument."Result Boolean" then
                if not HasServiceKey(LangModel.Code) and not HasUserKey(LangModel.Code) then
                    MissingCount += 1;
        until LangModel.Next() = 0;
        exit(MissingCount);
    end;

    local procedure BuildDescription(DescriptionTok: Text; LangModelCode: Code[20]): Text[100]
    begin
        exit(CopyStr(StrSubstNo(DescriptionTok, LangModelCode), 1, 100));
    end;

    local procedure CheckLangModelCode(LangModelCode: Code[20])
    begin
        if LangModelCode = '' then
            Error(LanguageModelCodeMissingErr);
    end;

    local procedure CheckServiceKeyPermission()
    begin
        if not HasServiceKeyPermission() then
            Error(NoServiceKeyPermissionErr);
    end;
}
