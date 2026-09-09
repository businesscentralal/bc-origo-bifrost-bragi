namespace Origo.Bifrost.Bragi.Test;
using Origo.Bifrost;
using Origo.Bifrost.Bragi;

using System.TestLibraries.Utilities;

/// <summary>
/// Tests for the Skill blob round-trip on the base "Bifrost Language Model ori" table.
/// </summary>
codeunit 96003 "Bifrost Language Model Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Any: Codeunit Any;
        IsInitialized: Boolean;

    local procedure Initialize()
    begin
        if IsInitialized then
            exit;

        IsInitialized := true;
    end;

    [Test]
    procedure SetSkill_GetSkill_ReturnsStoredText()
    var
        BifrostLanguageModel: Record "Bifrost Language Model ori";
        SkillText: Text;
    begin
        // [SCENARIO] SetSkill stores markdown text that GetSkill retrieves correctly.
        Initialize();

        // [GIVEN] A new Bifrost Language Model record
        BifrostLanguageModel.Init();
        BifrostLanguageModel.Code := CopyStr('X-' + Format(Any.IntegerInRange(1000, 9999)), 1, MaxStrLen(BifrostLanguageModel.Code));
        BifrostLanguageModel.Insert(true);

        // [GIVEN] Skill text content
        SkillText := '# Test Skill' + '\n\nThis is a test skill with **markdown** formatting.';

        // [WHEN] SetSkill is called and the record is modified
        BifrostLanguageModel.SetSkill(SkillText);
        BifrostLanguageModel.Modify(true);

        // [THEN] GetSkill returns the stored text
        BifrostLanguageModel.Get(BifrostLanguageModel.Code);
        Assert.AreEqual(SkillText, BifrostLanguageModel.GetSkill(), 'GetSkill should return the stored skill text.');
    end;

    [Test]
    procedure GetSkill_NoContent_ReturnsEmptyString()
    var
        BifrostLanguageModel: Record "Bifrost Language Model ori";
    begin
        // [SCENARIO] GetSkill returns empty string when no blob content exists.
        Initialize();

        // [GIVEN] A new Bifrost Language Model with no skill set
        BifrostLanguageModel.Init();
        BifrostLanguageModel.Code := CopyStr('X-' + Format(CreateGuid(), 0, 4), 1, MaxStrLen(BifrostLanguageModel.Code));
        BifrostLanguageModel.Insert(true);

        // [WHEN] GetSkill is called
        // [THEN] Empty string is returned
        BifrostLanguageModel.Get(BifrostLanguageModel.Code);
        Assert.AreEqual('', BifrostLanguageModel.GetSkill(), 'GetSkill should return empty string when no skill is set.');
    end;

    [Test]
    procedure SetSkill_LargeContent_RoundTripsCorrectly()
    var
        BifrostLanguageModel: Record "Bifrost Language Model ori";
        ContentLineTok: Label '## Section %1 - Content line with some detail about the skill.', Locked = true;
        SkillText: Text;
        Builder: TextBuilder;
        i: Integer;
    begin
        // [SCENARIO] SetSkill handles large markdown content correctly.
        Initialize();

        // [GIVEN] A new Bifrost Language Model record
        BifrostLanguageModel.Init();
        BifrostLanguageModel.Code := CopyStr('X-' + Format(CreateGuid(), 0, 4), 1, MaxStrLen(BifrostLanguageModel.Code));
        BifrostLanguageModel.Insert(true);

        // [GIVEN] Large skill text (simulating a real SKILL.md file)
        Builder.AppendLine('# Large Skill Document');
        Builder.AppendLine('');
        for i := 1 to 100 do
            Builder.AppendLine(StrSubstNo(ContentLineTok, i));
        SkillText := Builder.ToText();

        // [WHEN] SetSkill is called and the record is modified
        BifrostLanguageModel.SetSkill(SkillText);
        BifrostLanguageModel.Modify(true);

        // [THEN] GetSkill returns the same large text
        BifrostLanguageModel.Get(BifrostLanguageModel.Code);
        Assert.AreEqual(SkillText, BifrostLanguageModel.GetSkill(), 'GetSkill should return the full large skill text.');
    end;

    [Test]
    procedure SetSkill_OverwriteExisting_ReturnsNewContent()
    var
        BifrostLanguageModel: Record "Bifrost Language Model ori";
        FirstSkill: Text;
        SecondSkill: Text;
    begin
        // [SCENARIO] SetSkill overwrites existing skill content.
        Initialize();

        // [GIVEN] A record with existing skill content
        BifrostLanguageModel.Init();
        BifrostLanguageModel.Code := CopyStr('X-' + Format(CreateGuid(), 0, 4), 1, MaxStrLen(BifrostLanguageModel.Code));
        BifrostLanguageModel.Insert(true);
        FirstSkill := '# First Skill Version';
        BifrostLanguageModel.SetSkill(FirstSkill);
        BifrostLanguageModel.Modify(true);

        // [WHEN] SetSkill is called again with new content
        SecondSkill := '# Second Skill Version - Updated';
        BifrostLanguageModel.Get(BifrostLanguageModel.Code);
        BifrostLanguageModel.SetSkill(SecondSkill);
        BifrostLanguageModel.Modify(true);

        // [THEN] GetSkill returns the new content, not the old
        BifrostLanguageModel.Get(BifrostLanguageModel.Code);
        Assert.AreEqual(SecondSkill, BifrostLanguageModel.GetSkill(), 'GetSkill should return the overwritten skill text.');
    end;
}
