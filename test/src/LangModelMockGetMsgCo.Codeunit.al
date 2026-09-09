namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;

/// <summary>
/// Mock message type implementation used by the MCP tool server tests to verify that
/// list_message_types honours the IsEnabled() flag of a message type.
/// </summary>
codeunit 96007 "LangModel Mock Get Msg Co" implements "Msg Interface ori"
{
    SingleInstance = true;

    var
        ResponseText: Text;
        EnabledState: Boolean;
        EnabledStateSet: Boolean;

    procedure IsEnabled(): Boolean
    begin
        if EnabledStateSet then
            exit(EnabledState);
        exit(true);
    end;

    procedure GetFilterTableNo() FilterTableId: Integer
    begin
    end;

    procedure GetDescription() Description: Text[250]
    begin
    end;

    procedure GetMessageDirection() MessageDirection: Enum "Msg Direction ori"
    begin
    end;

    procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    begin
    end;

    procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    begin
        Argument.SetResponseText(ResponseText);
    end;

    /// <summary>
    /// Sets the text the mock returns from ExecuteBifrostTask.
    /// </summary>
    procedure SetResponseText(NewResponseText: Text)
    begin
        ResponseText := NewResponseText;
    end;

    /// <summary>
    /// Forces IsEnabled() to return the given value.
    /// </summary>
    procedure SetEnabled(NewEnabled: Boolean)
    begin
        EnabledState := NewEnabled;
        EnabledStateSet := true;
    end;

    /// <summary>
    /// Restores the default IsEnabled() behaviour.
    /// </summary>
    procedure ResetEnabled()
    begin
        EnabledStateSet := false;
    end;
}
