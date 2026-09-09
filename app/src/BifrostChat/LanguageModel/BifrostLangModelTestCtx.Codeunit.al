namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

/// <summary>
/// SingleInstance side-channel that lets the Language Model Card pass the current
/// record context to provider TestConnection implementations.
/// </summary>
codeunit 10035384 "Bifrost LangModel Test Ctx ori"
{
    Access = Public;
    SingleInstance = true;

    var
        RoleCode: Code[20];
        HasContext: Boolean;

    /// <summary>
    /// Stores the language model code being tested. Call before Provider.TestConnection.
    /// </summary>
    procedure SetLanguageModel(NewRoleCode: Code[20])
    begin
        RoleCode := NewRoleCode;
        HasContext := true;
    end;

    /// <summary>
    /// Clears the stored context. Call after TestConnection returns.
    /// </summary>
    procedure ClearLanguageModel()
    begin
        Clear(RoleCode);
        HasContext := false;
    end;

    /// <summary>
    /// Tries to load the language model record from the stored context.
    /// Returns false when no context was set (caller should fall back to default resolution).
    /// </summary>
    procedure TryGetLanguageModel(var BifrostLanguageModel: Record "Bifrost Language Model ori"): Boolean
    begin
        if not HasContext then
            exit(false);
        exit(BifrostLanguageModel.Get(RoleCode));
    end;
}
