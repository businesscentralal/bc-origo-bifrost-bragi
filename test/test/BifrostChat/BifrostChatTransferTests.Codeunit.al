namespace Origo.Bifrost.LanguageModels.Test;
using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;

using System.TestLibraries.Utilities;

/// <summary>
/// Tests for the "Bifrost Chat Transfer ori" SingleInstance context-handoff codeunit
/// used between the Bifrost Chat FactBox and the Focus page.
/// </summary>
codeunit 96004 "Bifrost Chat Transfer Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Any: Codeunit Any;

    [Test]
    procedure SetContext_AllGetters_ReturnStoredValues()
    var
        BifrostChatTransfer: Codeunit "Bifrost Chat Transfer ori";
        TableId: Integer;
        RecordSystemId: Guid;
        HistoryJson: Text;
    begin
        // [SCENARIO] SetContext stores values that all getters return correctly.
        BifrostChatTransfer.Clear();

        // [GIVEN] Random context values
        TableId := Any.IntegerInRange(1, 99999);
        RecordSystemId := CreateGuid();
        HistoryJson := '[{"role":"user","content":"Hello"}]';

        // [WHEN] SetContext is called
        BifrostChatTransfer.SetContext(TableId, RecordSystemId, HistoryJson);

        // [THEN] All getters return the stored values
        Assert.AreEqual(TableId, BifrostChatTransfer.GetTableId(), 'GetTableId should return stored table ID.');
        Assert.AreEqual(RecordSystemId, BifrostChatTransfer.GetRecordSystemId(), 'GetRecordSystemId should return stored SystemId.');
        Assert.AreEqual(HistoryJson, BifrostChatTransfer.GetHistoryJson(), 'GetHistoryJson should return stored JSON.');
    end;

    [Test]
    procedure SetContext_HasData_ReturnsTrue()
    var
        BifrostChatTransfer: Codeunit "Bifrost Chat Transfer ori";
    begin
        // [SCENARIO] HasData returns true after SetContext is called.
        BifrostChatTransfer.Clear();

        // [GIVEN] No context set
        Assert.IsFalse(BifrostChatTransfer.HasData(), 'HasData should be false after Clear.');

        // [WHEN] SetContext is called
        BifrostChatTransfer.SetContext(18, CreateGuid(), '[]');

        // [THEN] HasData returns true
        Assert.IsTrue(BifrostChatTransfer.HasData(), 'HasData should be true after SetContext.');
    end;

    [Test]
    procedure Clear_AfterSetContext_HasDataReturnsFalse()
    var
        BifrostChatTransfer: Codeunit "Bifrost Chat Transfer ori";
    begin
        // [SCENARIO] Clear resets the stored context.

        // [GIVEN] Context has been set
        BifrostChatTransfer.SetContext(36, CreateGuid(), '{"test":true}');
        Assert.IsTrue(BifrostChatTransfer.HasData(), 'HasData should be true before Clear.');

        // [WHEN] Clear is called
        BifrostChatTransfer.Clear();

        // [THEN] HasData returns false and getters return defaults
        Assert.IsFalse(BifrostChatTransfer.HasData(), 'HasData should be false after Clear.');
        Assert.AreEqual(0, BifrostChatTransfer.GetTableId(), 'GetTableId should be 0 after Clear.');
        Assert.AreEqual('', BifrostChatTransfer.GetHistoryJson(), 'GetHistoryJson should be empty after Clear.');
        Assert.AreEqual('', BifrostChatTransfer.GetDataCaption(), 'GetDataCaption should be empty after Clear.');
    end;

    [Test]
    procedure SetDataCaption_GetDataCaption_ReturnsStoredValue()
    var
        BifrostChatTransfer: Codeunit "Bifrost Chat Transfer ori";
        ExpectedCaption: Text;
    begin
        // [SCENARIO] SetDataCaption/GetDataCaption stores and retrieves the caption.
        BifrostChatTransfer.Clear();

        // [GIVEN] A caption value
        ExpectedCaption := 'Customer 10000 - Adatum Corporation';

        // [WHEN] SetDataCaption is called
        BifrostChatTransfer.SetDataCaption(ExpectedCaption);

        // [THEN] GetDataCaption returns the stored caption
        Assert.AreEqual(ExpectedCaption, BifrostChatTransfer.GetDataCaption(), 'GetDataCaption should return stored caption.');
    end;

    [Test]
    procedure SetContextSkill_GetContextSkill_ReturnsStoredValue()
    var
        BifrostChatTransfer: Codeunit "Bifrost Chat Transfer ori";
        ExpectedSkill: Text;
    begin
        // [SCENARIO] SetContextSkill/GetContextSkill round-trips the skill text.
        BifrostChatTransfer.Clear();

        // [GIVEN] A markdown skill snippet
        ExpectedSkill := '## Context Skill' + '\nUse this when summarizing the record.';

        // [WHEN] SetContextSkill is called
        BifrostChatTransfer.SetContextSkill(ExpectedSkill);

        // [THEN] GetContextSkill returns the stored value
        Assert.AreEqual(ExpectedSkill, BifrostChatTransfer.GetContextSkill(), 'GetContextSkill should return stored skill text.');
    end;

    [Test]
    procedure SetContext_EmptyHistory_GetHistoryJsonReturnsEmpty()
    var
        BifrostChatTransfer: Codeunit "Bifrost Chat Transfer ori";
    begin
        // [SCENARIO] SetContext with empty history stores empty string.
        BifrostChatTransfer.Clear();

        // [WHEN] SetContext is called with empty history
        BifrostChatTransfer.SetContext(27, CreateGuid(), '');

        // [THEN] GetHistoryJson returns empty string and HasData is still true
        Assert.AreEqual('', BifrostChatTransfer.GetHistoryJson(), 'GetHistoryJson should return empty string.');
        Assert.IsTrue(BifrostChatTransfer.HasData(), 'HasData should be true even with empty history.');
    end;
}
