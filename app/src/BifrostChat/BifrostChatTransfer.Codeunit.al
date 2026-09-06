namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

/// <summary>
/// SingleInstance codeunit that temporarily holds chat context when the user
/// switches from the Bifrost Chat FactBox to the Focus page (and back). Keeps the
/// active record, the data caption, the language-model/context skill and the serialized
/// message history alive across the modal transition.
/// </summary>
codeunit 10035383 "Bifrost Chat Transfer ori"
{
    Access = Public;
    SingleInstance = true;

    var
        StoredTableId: Integer;
        StoredRecordSystemId: Guid;
        StoredHistoryJson: Text;
        StoredDataCaption: Text;
        StoredContextSkill: Text;
        HasContext: Boolean;

    /// <summary>
    /// Stores the chat context for the focus page to pick up.
    /// </summary>
    /// <param name="TableId">The table number of the current record.</param>
    /// <param name="RecordSystemId">The SystemId of the current record.</param>
    /// <param name="HistoryJson">Serialized chat messages JSON array.</param>
    procedure SetContext(TableId: Integer; RecordSystemId: Guid; HistoryJson: Text)
    begin
        StoredTableId := TableId;
        StoredRecordSystemId := RecordSystemId;
        StoredHistoryJson := HistoryJson;
        HasContext := true;
    end;

    /// <summary>
    /// Stores the data caption text for the focus page to display.
    /// </summary>
    /// <param name="DataCaption">The caption text to show on the page.</param>
    procedure SetDataCaption(DataCaption: Text)
    begin
        StoredDataCaption := DataCaption;
    end;

    /// <summary>
    /// Stores the optional context-specific skill guidance for the focus page.
    /// </summary>
    /// <param name="ContextSkill">Markdown guidance to append to the chat prompt.</param>
    procedure SetContextSkill(ContextSkill: Text)
    begin
        StoredContextSkill := ContextSkill;
    end;

    /// <summary>
    /// Retrieves the stored data caption text.
    /// </summary>
    /// <returns>The caption text passed from the factbox.</returns>
    procedure GetDataCaption(): Text
    begin
        exit(StoredDataCaption);
    end;

    /// <summary>
    /// Retrieves the stored context-specific skill guidance.
    /// </summary>
    /// <returns>The context skill text passed from the factbox.</returns>
    procedure GetContextSkill(): Text
    begin
        exit(StoredContextSkill);
    end;

    /// <summary>
    /// Retrieves the stored table ID.
    /// </summary>
    /// <returns>The table number passed from the factbox.</returns>
    procedure GetTableId(): Integer
    begin
        exit(StoredTableId);
    end;

    /// <summary>
    /// Retrieves the stored record system ID.
    /// </summary>
    /// <returns>The SystemId passed from the factbox.</returns>
    procedure GetRecordSystemId(): Guid
    begin
        exit(StoredRecordSystemId);
    end;

    /// <summary>
    /// Retrieves the stored chat history JSON.
    /// </summary>
    /// <returns>The serialized messages array.</returns>
    procedure GetHistoryJson(): Text
    begin
        exit(StoredHistoryJson);
    end;

    /// <summary>
    /// Checks whether context data has been stored.
    /// </summary>
    /// <returns>True if SetContext has been called.</returns>
    procedure HasData(): Boolean
    begin
        exit(HasContext);
    end;

    /// <summary>
    /// Clears the stored context after the focus page has consumed it.
    /// </summary>
    procedure Clear()
    var
        EmptyGuid: Guid;
    begin
        StoredTableId := 0;
        StoredRecordSystemId := EmptyGuid;
        StoredHistoryJson := '';
        StoredDataCaption := '';
        StoredContextSkill := '';
        HasContext := false;
    end;
}
