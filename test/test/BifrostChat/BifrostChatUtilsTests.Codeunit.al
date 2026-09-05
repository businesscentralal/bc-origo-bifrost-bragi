namespace Origo.Bifrost.Bragi.Test;
using Origo.Bifrost;
using Origo.Bifrost.Bragi;

using System.TestLibraries.Utilities;

codeunit 96005 "Bifrost Chat Utils Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure TruncateContent_ShortText_ReturnsUnchanged()
    var
        ChatUtils: Codeunit "Bifrost Chat Utils ori";
        Result: Text;
    begin
        // [SCENARIO] Content shorter than limit is returned unchanged.
        Result := ChatUtils.TruncateContent('Hello world', 100);
        Assert.AreEqual('Hello world', Result, 'Short content should not be truncated.');
    end;

    [Test]
    procedure TruncateContent_ExactLimit_ReturnsUnchanged()
    var
        ChatUtils: Codeunit "Bifrost Chat Utils ori";
        Result: Text;
    begin
        // [SCENARIO] Content exactly at limit is returned unchanged.
        Result := ChatUtils.TruncateContent('12345', 5);
        Assert.AreEqual('12345', Result, 'Content at exact limit should not be truncated.');
    end;

    [Test]
    procedure TruncateContent_LongText_Truncates()
    var
        ChatUtils: Codeunit "Bifrost Chat Utils ori";
        Result: Text;
    begin
        // [SCENARIO] Content exceeding limit is truncated with marker.
        Result := ChatUtils.TruncateContent('ABCDEFGHIJKLMNOP', 10);
        Assert.IsTrue(Result.StartsWith('ABCDEFGHIJ'), 'Should start with first 10 chars.');
        Assert.IsTrue(Result.Contains('[truncated'), 'Should contain truncation marker.');
        Assert.IsTrue(Result.Contains('16 chars total'), 'Should state original length.');
    end;

    [Test]
    procedure TruncateContent_DefaultLimit_Uses65000()
    var
        ChatUtils: Codeunit "Bifrost Chat Utils ori";
        LongText: Text;
        Result: Text;
        i: Integer;
    begin
        // [SCENARIO] Passing MaxChars=0 uses default of 65000.
        for i := 1 to 7000 do
            LongText += 'ABCDEFGHIJ';
        Result := ChatUtils.TruncateContent(LongText, 0);
        Assert.IsTrue(Result.Contains('[truncated'), 'Should truncate at default limit.');
        Assert.IsTrue(StrLen(Result) < 65200, 'Result should be near 65000 chars.');
    end;

    [Test]
    procedure CompactOlderToolResults_KeepsLastN()
    var
        ChatUtils: Codeunit "Bifrost Chat Utils ori";
        Messages: JsonArray;
        MessageObject: JsonObject;
        Content: Text;
        i: Integer;
    begin
        // [SCENARIO] CompactOlderToolResults keeps last N tool results at full size.
        // Add 5 tool messages with 1000-char content each
        for i := 1 to 5 do begin
            Clear(MessageObject);
            MessageObject.Add('role', 'tool');
            MessageObject.Add('tool_call_id', 'call_' + Format(i));
            Content := PadStr('', 1000, 'X');
            MessageObject.Add('content', Content);
            Messages.Add(MessageObject);
        end;

        ChatUtils.CompactOlderToolResults(Messages, 2, 100);

        // First 3 should be compacted, last 2 at full size
        Assert.AreEqual(5, Messages.Count(), 'Should still have 5 messages.');
        Assert.IsTrue(GetMessageContent(Messages, 0).Contains('[truncated'), 'Message 0 should be truncated.');
        Assert.IsTrue(GetMessageContent(Messages, 1).Contains('[truncated'), 'Message 1 should be truncated.');
        Assert.IsTrue(GetMessageContent(Messages, 2).Contains('[truncated'), 'Message 2 should be truncated.');
        Assert.AreEqual(1000, StrLen(GetMessageContent(Messages, 3)), 'Message 3 should be full size.');
        Assert.AreEqual(1000, StrLen(GetMessageContent(Messages, 4)), 'Message 4 should be full size.');
    end;

    [Test]
    procedure CompactOlderToolResults_PreservesNonToolMessages()
    var
        ChatUtils: Codeunit "Bifrost Chat Utils ori";
        Messages: JsonArray;
        SystemMsg: JsonObject;
        UserMsg: JsonObject;
        ToolMsg: JsonObject;
    begin
        // [SCENARIO] Non-tool messages are never compacted.
        SystemMsg.Add('role', 'system');
        SystemMsg.Add('content', PadStr('', 2000, 'S'));
        Messages.Add(SystemMsg);

        UserMsg.Add('role', 'user');
        UserMsg.Add('content', PadStr('', 2000, 'U'));
        Messages.Add(UserMsg);

        ToolMsg.Add('role', 'tool');
        ToolMsg.Add('tool_call_id', 'call_1');
        ToolMsg.Add('content', PadStr('', 2000, 'T'));
        Messages.Add(ToolMsg);

        ChatUtils.CompactOlderToolResults(Messages, 0, 100);

        Assert.AreEqual(2000, StrLen(GetMessageContent(Messages, 0)), 'System message should be unchanged.');
        Assert.AreEqual(2000, StrLen(GetMessageContent(Messages, 1)), 'User message should be unchanged.');
    end;

    [Test]
    procedure CompactOlderToolResults_SmallResults_Untouched()
    var
        ChatUtils: Codeunit "Bifrost Chat Utils ori";
        Messages: JsonArray;
        ToolMsg: JsonObject;
    begin
        // [SCENARIO] Tool results already under the limit are not modified.
        ToolMsg.Add('role', 'tool');
        ToolMsg.Add('tool_call_id', 'call_1');
        ToolMsg.Add('content', 'Small result');
        Messages.Add(ToolMsg);

        ChatUtils.CompactOlderToolResults(Messages, 0, 500);

        Assert.AreEqual('Small result', GetMessageContent(Messages, 0), 'Small result should be unchanged.');
    end;

    [Test]
    procedure TrimMessageHistory_UnderBudget_NoChange()
    var
        ChatUtils: Codeunit "Bifrost Chat Utils ori";
        Messages: JsonArray;
        UserMsg: JsonObject;
    begin
        // [SCENARIO] Messages under budget are not trimmed.
        UserMsg.Add('role', 'user');
        UserMsg.Add('content', 'Hello');
        Messages.Add(UserMsg);

        ChatUtils.TrimMessageHistory(Messages, 100000);

        Assert.AreEqual(1, Messages.Count(), 'Should keep all messages when under budget.');
    end;

    [Test]
    procedure TrimMessageHistory_OverBudget_DropsOldest()
    var
        ChatUtils: Codeunit "Bifrost Chat Utils ori";
        Messages: JsonArray;
        SystemMsg: JsonObject;
        Msg: JsonObject;
        i: Integer;
    begin
        // [SCENARIO] TrimMessageHistory drops oldest non-system messages when over budget.
        SystemMsg.Add('role', 'system');
        SystemMsg.Add('content', 'System prompt');
        Messages.Add(SystemMsg);

        for i := 1 to 10 do begin
            Clear(Msg);
            Msg.Add('role', 'user');
            Msg.Add('content', 'Message ' + Format(i) + ': ' + PadStr('', 500, 'X'));
            Messages.Add(Msg);
        end;

        ChatUtils.TrimMessageHistory(Messages, 3000);

        // System message should survive
        Assert.AreEqual('system', GetMessageRole(Messages, 0), 'First message should be system.');
        // Some older messages should be dropped
        Assert.IsTrue(Messages.Count() < 11, 'Should have fewer messages after trim.');
    end;

    [Test]
    procedure TrimMessageHistory_PreservesSystemMessage()
    var
        ChatUtils: Codeunit "Bifrost Chat Utils ori";
        Messages: JsonArray;
        SystemMsg: JsonObject;
        UserMsg: JsonObject;
    begin
        // [SCENARIO] System messages are never dropped by TrimMessageHistory.
        SystemMsg.Add('role', 'system');
        SystemMsg.Add('content', PadStr('', 1000, 'S'));
        Messages.Add(SystemMsg);

        UserMsg.Add('role', 'user');
        UserMsg.Add('content', PadStr('', 1000, 'U'));
        Messages.Add(UserMsg);

        // Budget smaller than total but system must survive
        ChatUtils.TrimMessageHistory(Messages, 500);

        Assert.IsTrue(Messages.Count() >= 1, 'Should have at least system message.');
        Assert.AreEqual('system', GetMessageRole(Messages, 0), 'System message should survive.');
    end;

    [Test]
    procedure EstimateTokens_RoughCalc()
    var
        ChatUtils: Codeunit "Bifrost Chat Utils ori";
    begin
        // [SCENARIO] EstimateTokens returns chars/4 approximation.
        Assert.AreEqual(25, ChatUtils.EstimateTokens(PadStr('', 100, 'A')), 'Expected 100/4 = 25 tokens.');
        Assert.AreEqual(0, ChatUtils.EstimateTokens(''), 'Empty string should be 0 tokens.');
        Assert.AreEqual(1, ChatUtils.EstimateTokens('Hell'), 'Expected 4/4 = 1 token.');
    end;

    [Test]
    procedure SetDefaults_OverridesValues()
    var
        ChatUtils: Codeunit "Bifrost Chat Utils ori";
        Result: Text;
    begin
        // [SCENARIO] SetDefaults changes the truncation limits.
        ChatUtils.SetDefaults(50, 1000);
        Result := ChatUtils.TruncateContent(PadStr('', 200, 'X'), 0);
        Assert.IsTrue(Result.Contains('[truncated'), 'Should truncate at custom default of 50.');
        Assert.IsTrue(StrLen(Result) < 100, 'Result should be near 50 chars.');
    end;

    // -- Helpers --

    [Test]
    procedure GetIdentityJson_ReturnsUserIdentityWithoutEnvelope()
    var
        ChatUtils: Codeunit "Bifrost Chat Utils ori";
        IdentityJson: JsonObject;
        UserToken: JsonToken;
        Dummy: JsonToken;
    begin
        // [SCENARIO] GetIdentityJson runs Help.WhoAmI.Get and returns the identity payload
        // without the response envelope status and without the personal system prompt.
        IdentityJson := ChatUtils.GetIdentityJson();

        Assert.IsTrue(IdentityJson.Get('user', UserToken), 'Identity should contain a user object.');
        Assert.IsTrue(IdentityJson.Get('companyInfo', Dummy), 'Identity should contain companyInfo.');
        Assert.IsFalse(IdentityJson.Get('status', Dummy), 'Identity should not carry the response envelope status.');
        Assert.IsFalse(IdentityJson.Get('systemPrompt', Dummy), 'Identity should not carry the personal system prompt.');
    end;

    [Test]
    procedure GetIdentityJson_UserObjectCarriesCurrentUser()
    var
        ChatUtils: Codeunit "Bifrost Chat Utils ori";
        IdentityJson: JsonObject;
        UserToken: JsonToken;
        SecurityIdToken: JsonToken;
    begin
        // [SCENARIO] The identity payload identifies the calling user.
        IdentityJson := ChatUtils.GetIdentityJson();
        IdentityJson.Get('user', UserToken);

        if UserToken.IsObject() then begin
            Assert.IsTrue(UserToken.AsObject().Get('userSecurityId', SecurityIdToken), 'User object should carry userSecurityId.');
            Assert.AreEqual(
                Format(UserSecurityId(), 0, 4),
                SecurityIdToken.AsValue().AsText(),
                'userSecurityId should be the calling user.');
        end;
    end;

    local procedure GetMessageContent(Messages: JsonArray; Index: Integer): Text
    var
        Token: JsonToken;
        MsgObject: JsonObject;
        ContentToken: JsonToken;
    begin
        Messages.Get(Index, Token);
        MsgObject := Token.AsObject();
        if MsgObject.Get('content', ContentToken) then
            if ContentToken.IsValue() then
                exit(ContentToken.AsValue().AsText());
    end;

    local procedure GetMessageRole(Messages: JsonArray; Index: Integer): Text
    var
        Token: JsonToken;
        MsgObject: JsonObject;
        RoleToken: JsonToken;
    begin
        Messages.Get(Index, Token);
        MsgObject := Token.AsObject();
        if MsgObject.Get('role', RoleToken) then
            exit(RoleToken.AsValue().AsText());
    end;
}
