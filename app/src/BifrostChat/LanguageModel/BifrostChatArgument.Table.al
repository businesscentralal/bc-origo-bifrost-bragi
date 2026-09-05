namespace Origo.Bifrost.Bragi;
using Microsoft.Utilities;

using Origo.Bifrost;

/// <summary>
/// Argument table for the single-procedure Bifrost Language Model Provider interface.
/// The base extension populates config fields and sets "Procedure Type" before
/// calling Provider.Execute(Argument). Providers read inputs, perform the
/// operation, and write outputs. Large text I/O uses global variables.
/// </summary>
table 10035337 "Bifrost Chat Argument ori"
{
    Caption = 'Bifrost Chat Argument', Comment = 'is-IS=Bifröst spjallvi\u00f0fang';
    DataClassification = SystemMetadata;
    TableType = Temporary;

    fields
    {
        field(1; "Language Model SystemId"; Guid)
        {
            Caption = 'Language Model SystemId';
            DataClassification = SystemMetadata;
        }
        field(2; "Procedure Type"; Enum "Bifrost Chat Proc. Type ori")
        {
            Caption = 'Procedure Type';
            DataClassification = SystemMetadata;
        }
        field(10; "Base URL"; Text[250])
        {
            Caption = 'Base URL';
            DataClassification = SystemMetadata;
        }
        field(11; Model; Text[100])
        {
            Caption = 'Model';
            DataClassification = SystemMetadata;
        }
        field(12; "Timeout Ms"; Integer)
        {
            Caption = 'Timeout (ms)';
            DataClassification = SystemMetadata;
        }
        field(13; "Max Tokens"; Integer)
        {
            Caption = 'Max Tokens';
            DataClassification = SystemMetadata;
        }
        field(14; "Chat Path"; Text[250])
        {
            Caption = 'Chat Path';
            DataClassification = SystemMetadata;
        }
        field(15; "Models Path"; Text[250])
        {
            Caption = 'Models Path';
            DataClassification = SystemMetadata;
        }
        field(40; "Debug Mode"; Boolean)
        {
            Caption = 'Debug Mode';
            DataClassification = SystemMetadata;
        }
        field(50; "Result Boolean"; Boolean)
        {
            Caption = 'Result Boolean';
            DataClassification = SystemMetadata;
        }
        field(51; "Result Integer"; Integer)
        {
            Caption = 'Result Integer';
            DataClassification = SystemMetadata;
        }
        field(52; "Input Tokens"; Integer)
        {
            Caption = 'Input Tokens';
            DataClassification = SystemMetadata;
        }
        field(53; "Output Tokens"; Integer)
        {
            Caption = 'Output Tokens';
            DataClassification = SystemMetadata;
        }
    }

    keys
    {
        key(PK; "Language Model SystemId")
        {
            Clustered = true;
        }
    }

    var
        TempModels: Record "Name/Value Buffer" temporary;
        ApiKeyValue: Text;
        SkillValue: Text;
        UserPromptValue: Text;
        PayloadValue: Text;
        ConversationStateValue: Text;
        ToolResultsValue: Text;
        ResultTextValue: Text;
        ErrorMessageValue: Text;

    // --- API Key (blob for NonDebuggable) ---

    [NonDebuggable]
    procedure SetApiKey(ApiKey: Text)
    begin
        ApiKeyValue := ApiKey;
    end;

    [NonDebuggable]
    procedure GetApiKey(): Text
    begin
        exit(ApiKeyValue);
    end;

    // --- Large text I/O via global variables ---

    procedure SetSkill(Value: Text)
    begin
        SkillValue := Value;
    end;

    procedure GetSkill(): Text
    begin
        exit(SkillValue);
    end;

    procedure SetUserPrompt(Value: Text)
    begin
        UserPromptValue := Value;
    end;

    procedure GetUserPrompt(): Text
    begin
        exit(UserPromptValue);
    end;

    procedure SetPayload(Value: Text)
    begin
        PayloadValue := Value;
    end;

    procedure GetPayload(): Text
    begin
        exit(PayloadValue);
    end;

    procedure SetConversationState(Value: Text)
    begin
        ConversationStateValue := Value;
    end;

    procedure GetConversationState(): Text
    begin
        exit(ConversationStateValue);
    end;

    procedure SetToolResults(Value: Text)
    begin
        ToolResultsValue := Value;
    end;

    procedure GetToolResults(): Text
    begin
        exit(ToolResultsValue);
    end;

    procedure SetResultText(Value: Text)
    begin
        ResultTextValue := Value;
    end;

    procedure GetResultText(): Text
    begin
        exit(ResultTextValue);
    end;

    procedure SetErrorMessage(Value: Text)
    begin
        ErrorMessageValue := Value;
    end;

    procedure GetErrorMessage(): Text
    begin
        exit(ErrorMessageValue);
    end;

    // --- Model buffer for GetAvailableModels ---

    procedure GetModels(var TempNameValueBuffer: Record "Name/Value Buffer" temporary)
    begin
        TempNameValueBuffer.Copy(TempModels, true);
    end;

    procedure SetModels(var TempNameValueBuffer: Record "Name/Value Buffer" temporary)
    begin
        TempModels.Copy(TempNameValueBuffer, true);
    end;
}
