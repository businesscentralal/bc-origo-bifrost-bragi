namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;
using System.Reflection;

/// <summary>
/// Data take-over for the published Origo Cloud Events Chat app, which this feature
/// replaces. Called from "Copilot Install ori".OnInstallAppPerCompany. The legacy app's
/// only persistent table is a permission gate with no stored rows, so this is a
/// straightforward existence check plus an empty-table copy, kept here (rather than
/// skipped) so the take-over is auditable and consistent with every other Bifrost
/// replacement app.
/// </summary>
codeunit 10035420 "Chat Providers Install ori"
{
    Access = Internal;

    /// <summary>
    /// Copies rows from the legacy "CE Chat Service Gate ori" table (Origo Cloud Events Chat,
    /// table 10035495) into the new "Chat Svc Gate ori" table when the legacy app is still
    /// installed in this company and the new table is still empty.
    /// </summary>
    internal procedure TakeOverChatProviderData()
    var
        ChatSvcGate: Record "Chat Svc Gate ori";
        TableMetadata: Record "Table Metadata";
        DataTransfer: DataTransfer;
        LegacyServiceGateTableId: Integer;
        RowsCopied: Integer;
    begin
        LegacyServiceGateTableId := 10035495; // "CE Chat Service Gate ori" in Origo Cloud Events Chat

        if not TableMetadata.Get(LegacyServiceGateTableId) then
            exit; // legacy app not installed in this company — nothing to take over

        if not ChatSvcGate.IsEmpty() then
            exit; // already populated — never overwrite

        DataTransfer.SetTables(LegacyServiceGateTableId, Database::"Chat Svc Gate ori");
        DataTransfer.AddFieldValue(1, ChatSvcGate.FieldNo("Primary Key"));
        DataTransfer.UpdateAuditFields(false);
        DataTransfer.CopyRows();
        RowsCopied := ChatSvcGate.Count();

        LogTakeOver(RowsCopied);
    end;

    local procedure LogTakeOver(RowsCopied: Integer)
    var
        CustomDimensions: Dictionary of [Text, Text];
        TelemetryTagTok: Label 'ORI-BIF-0420', Locked = true;
        TakeOverMsg: Label 'Chat provider data take-over from Origo Cloud Events Chat completed.', Locked = true;
    begin
        CustomDimensions.Add('RowsCopied', Format(RowsCopied));
        Session.LogMessage(TelemetryTagTok, TakeOverMsg, Verbosity::Normal,
            DataClassification::SystemMetadata, TelemetryScope::ExtensionPublisher, CustomDimensions);
    end;
}
