namespace Origo.Bifrost.LanguageModels;
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
    Caption = 'Bifrost Chat Argument', Comment = 'is-IS=Bifröst spjallviðfang';
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
        ApiKeyValue: SecretText;
        SkillValue: Text;
        UserPromptValue: Text;
        PayloadValue: Text;
        ConversationStateValue: Text;
        ToolResultsValue: Text;
        ResultTextValue: Text;
        ErrorMessageValue: Text;

    // --- API Key (SecretText, never persisted) ---

    /// <summary>
    /// Stores the API key the provider must use for this request. The value is held as
    /// SecretText and never reaches a table field, telemetry or an error message.
    /// </summary>
    /// <param name="ApiKey">The API key read from the Bifrost secret store.</param>
    [NonDebuggable]
    procedure SetApiKey(ApiKey: SecretText)
    begin
        ApiKeyValue := ApiKey;
    end;

    /// <summary>
    /// Returns the API key. It stays SecretText all the way into the HTTP header or the
    /// request URL - the value is never converted to Text.
    /// </summary>
    /// <returns>SecretText. The API key, empty when none is set.</returns>
    [NonDebuggable]
    procedure GetApiKey(): SecretText
    begin
        exit(ApiKeyValue);
    end;

    /// <summary>
    /// Returns whether an API key is available for this request.
    /// </summary>
    /// <returns>Boolean. True when a non-empty key is set.</returns>
    procedure HasApiKey(): Boolean
    begin
        exit(not ApiKeyValue.IsEmpty());
    end;

    /// <summary>
    /// Returns the non-secret marker the chat control add-in uses to decide whether a key is
    /// configured. The add-in only tests the value for truthiness; the key itself never
    /// leaves the server.
    /// </summary>
    /// <returns>Text. A fixed marker when a key is set, otherwise an empty string.</returns>
    procedure GetApiKeyIndicator(): Text
    var
        ApiKeySetTok: Label 'set', Locked = true;
    begin
        if ApiKeyValue.IsEmpty() then
            exit('');
        exit(ApiKeySetTok);
    end;

    // --- Large text I/O via global variables ---

    /// <summary>
    /// Stores the skill text of the language model - the instructions the provider sends as the
    /// system message. This value and the other large texts below are held in global variables
    /// rather than table fields, because they are longer than any AL text field can hold.
    /// </summary>
    /// <param name="Value">The skill text of the language model.</param>
    procedure SetSkill(Value: Text)
    begin
        SkillValue := Value;
    end;

    /// <summary>
    /// Returns the skill text of the language model.
    /// </summary>
    /// <returns>Text. The skill text, empty when the language model has none.</returns>
    procedure GetSkill(): Text
    begin
        exit(SkillValue);
    end;

    /// <summary>
    /// Stores the personal system prompt of the current user, read from the user's Bifrost user
    /// setup. Providers append it to the skill text.
    /// </summary>
    /// <param name="Value">The personal system prompt of the current user.</param>
    procedure SetUserPrompt(Value: Text)
    begin
        UserPromptValue := Value;
    end;

    /// <summary>
    /// Returns the personal system prompt of the current user.
    /// </summary>
    /// <returns>Text. The personal system prompt, empty when the user has none.</returns>
    procedure GetUserPrompt(): Text
    begin
        exit(UserPromptValue);
    end;

    /// <summary>
    /// Stores the JSON request payload the provider must send to the language model. The chat
    /// control supplies it for SendChatMessage; the LLM.Prompt.Complete message type builds it
    /// for CompletePrompt.
    /// </summary>
    /// <param name="Value">The request payload as JSON text.</param>
    procedure SetPayload(Value: Text)
    begin
        PayloadValue := Value;
    end;

    /// <summary>
    /// Returns the JSON request payload for this call.
    /// </summary>
    /// <returns>Text. The request payload as JSON text.</returns>
    procedure GetPayload(): Text
    begin
        exit(PayloadValue);
    end;

    /// <summary>
    /// Stores the conversation state returned by the previous call, which carries the model name
    /// and the message history. Used by ContinueWithToolResults to resume a tool round.
    /// </summary>
    /// <param name="Value">The conversation state as JSON text.</param>
    procedure SetConversationState(Value: Text)
    begin
        ConversationStateValue := Value;
    end;

    /// <summary>
    /// Returns the conversation state to resume from.
    /// </summary>
    /// <returns>Text. The conversation state as JSON text, empty on a new conversation.</returns>
    procedure GetConversationState(): Text
    begin
        exit(ConversationStateValue);
    end;

    /// <summary>
    /// Stores the results of the tool calls the model asked for. The provider appends them to the
    /// message history before sending the next request.
    /// </summary>
    /// <param name="Value">The tool results as JSON text.</param>
    procedure SetToolResults(Value: Text)
    begin
        ToolResultsValue := Value;
    end;

    /// <summary>
    /// Returns the tool results to send back to the model.
    /// </summary>
    /// <returns>Text. The tool results as JSON text.</returns>
    procedure GetToolResults(): Text
    begin
        exit(ToolResultsValue);
    end;

    /// <summary>
    /// Stores the text result of the operation. The caller clears it before every call and reads
    /// it afterwards, so every operation that returns text writes it here.
    /// </summary>
    /// <param name="Value">The result of the operation.</param>
    procedure SetResultText(Value: Text)
    begin
        ResultTextValue := Value;
    end;

    /// <summary>
    /// Returns the text result the provider wrote for this operation.
    /// </summary>
    /// <returns>Text. The result of the operation, empty when it produced none.</returns>
    procedure GetResultText(): Text
    begin
        exit(ResultTextValue);
    end;

    /// <summary>
    /// Stores the message explaining why the operation failed. Providers set it instead of raising
    /// an error, so the caller decides how to present the failure.
    /// </summary>
    /// <param name="Value">The error message to report to the caller.</param>
    procedure SetErrorMessage(Value: Text)
    begin
        ErrorMessageValue := Value;
    end;

    /// <summary>
    /// Returns the error message of the last operation.
    /// </summary>
    /// <returns>Text. The error message, empty when the operation succeeded.</returns>
    procedure GetErrorMessage(): Text
    begin
        exit(ErrorMessageValue);
    end;

    // --- Model buffer for GetAvailableModels ---

    /// <summary>
    /// Copies the model list the provider produced for GetAvailableModels into the caller's buffer.
    /// </summary>
    /// <param name="TempNameValueBuffer">Temporary buffer that receives the model list.</param>
    procedure GetModels(var TempNameValueBuffer: Record "Name/Value Buffer" temporary)
    begin
        TempNameValueBuffer.Copy(TempModels, true);
    end;

    /// <summary>
    /// Stores the model list the provider read from the language model service. Each buffer entry
    /// holds one model identifier in both Name and Value.
    /// </summary>
    /// <param name="TempNameValueBuffer">Temporary buffer holding the models to return.</param>
    procedure SetModels(var TempNameValueBuffer: Record "Name/Value Buffer" temporary)
    begin
        TempModels.Copy(TempNameValueBuffer, true);
    end;
}
