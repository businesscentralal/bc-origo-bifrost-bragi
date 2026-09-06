namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

using System.Text;

/// <summary>
/// Shared utilities for Bifrost Chat providers to manage message history size.
/// Stateless — call from any provider's tool loop to keep context within budget.
/// </summary>
codeunit 10035388 "Bifrost Chat Utils ori"
{
    Access = Public;

    var
        DefaultMaxResultChars: Integer;
        DefaultMaxHistoryChars: Integer;
        StatusKeyTok: Label 'status', Locked = true;
        SystemPromptKeyTok: Label 'systemPrompt', Locked = true;

    /// <summary>
    /// Returns the Bifrost Foundation identity payload for the calling user by running the
    /// Help.WhoAmI.Get message type, with the response envelope status and the personal
    /// system prompt removed. Used by the chat pages when validating the client connection.
    /// </summary>
    /// <returns>JsonObject with the user, setup, role and company identity of the current user.</returns>
    procedure GetIdentityJson() IdentityJson: JsonObject
    var
        Argument: Record "Message Argument ori";
        MessageTypeImpl: Interface "Msg Interface ori";
    begin
        Argument.Init();
        Argument.Version := Argument.Version::"1.0";
        Argument.Type := Argument.Type::"Help.WhoAmI.Get";
        Argument."Date & Time" := CurrentDateTime();
        Argument.Insert();

        MessageTypeImpl := Argument.Type;
        MessageTypeImpl.ExecuteBifrostTask(Argument);

        IdentityJson := Argument.GetResponseJson();
        IdentityJson.Remove(StatusKeyTok);
        IdentityJson.Remove(SystemPromptKeyTok);
    end;

    /// <summary>
    /// Truncates tool result content that exceeds the character limit.
    /// </summary>
    procedure TruncateContent(Content: Text; MaxChars: Integer) Result: Text
    var
        TruncatedLbl: Label '... [truncated, %1 chars total]', Locked = true;
    begin
        if MaxChars <= 0 then
            MaxChars := GetDefaultMaxResultChars();
        if StrLen(Content) <= MaxChars then
            exit(Content);
        exit(CopyStr(Content, 1, MaxChars) + StrSubstNo(TruncatedLbl, StrLen(Content)));
    end;

    /// <summary>
    /// Shrinks tool result content in older messages while keeping the latest round intact.
    /// Call before building each API request to prevent message history from growing unbounded.
    /// </summary>
    procedure CompactOlderToolResults(var Messages: JsonArray; KeepLastNToolResults: Integer; MaxCharsPerResult: Integer)
    var
        MessageToken: JsonToken;
        MessageObject: JsonObject;
        NewMessages: JsonArray;
        Role: Text;
        Content: Text;
        ToolResultCount: Integer;
        TotalToolResults: Integer;
        i: Integer;
    begin
        if MaxCharsPerResult <= 0 then
            MaxCharsPerResult := 500;
        if KeepLastNToolResults <= 0 then
            KeepLastNToolResults := 5;

        // Count total tool results
        for i := 0 to Messages.Count() - 1 do begin
            Messages.Get(i, MessageToken);
            MessageObject := MessageToken.AsObject();
            if GetJsonText(MessageObject, 'role') = 'tool' then
                TotalToolResults += 1;
        end;

        // Rebuild array, truncating older tool results
        ToolResultCount := 0;
        for i := 0 to Messages.Count() - 1 do begin
            Messages.Get(i, MessageToken);
            MessageObject := MessageToken.AsObject();
            Role := GetJsonText(MessageObject, 'role');

            if Role = 'tool' then begin
                ToolResultCount += 1;
                // Keep the last N tool results at full size, compact the rest
                if ToolResultCount <= (TotalToolResults - KeepLastNToolResults) then begin
                    Content := GetJsonText(MessageObject, 'content');
                    if StrLen(Content) > MaxCharsPerResult then begin
                        MessageObject.Replace('content', TruncateContent(Content, MaxCharsPerResult));
                        NewMessages.Add(MessageObject);
                    end else
                        NewMessages.Add(MessageToken);
                end else
                    NewMessages.Add(MessageToken);
            end else
                NewMessages.Add(MessageToken);
        end;

        Messages := NewMessages;
    end;

    /// <summary>
    /// Trims oldest user/assistant message pairs when total history exceeds the character budget.
    /// Preserves the system message and the most recent exchanges.
    /// </summary>
    procedure TrimMessageHistory(var Messages: JsonArray; MaxTotalChars: Integer)
    var
        MessageToken: JsonToken;
        MessageObject: JsonObject;
        Role: Text;
        TotalChars: Integer;
        i: Integer;
        DropBefore: Integer;
        NewMessages: JsonArray;
    begin
        if MaxTotalChars <= 0 then
            MaxTotalChars := GetDefaultMaxHistoryChars();

        // Measure total
        for i := 0 to Messages.Count() - 1 do begin
            Messages.Get(i, MessageToken);
            TotalChars += EstimateMessageChars(MessageToken);
        end;

        if TotalChars <= MaxTotalChars then
            exit;

        // Find how many messages to drop from the front (skip system messages)
        DropBefore := 0;
        for i := 0 to Messages.Count() - 1 do begin
            if TotalChars <= MaxTotalChars then
                break;
            Messages.Get(i, MessageToken);
            MessageObject := MessageToken.AsObject();
            Role := GetJsonText(MessageObject, 'role');
            if Role = 'system' then
                DropBefore := i + 1
            else begin
                TotalChars -= EstimateMessageChars(MessageToken);
                DropBefore := i + 1;
            end;
        end;

        // Rebuild without dropped messages
        for i := 0 to Messages.Count() - 1 do begin
            Messages.Get(i, MessageToken);
            MessageObject := MessageToken.AsObject();
            Role := GetJsonText(MessageObject, 'role');
            if (Role = 'system') or (i >= DropBefore) then
                NewMessages.Add(MessageToken);
        end;

        Messages := NewMessages;
    end;

    /// <summary>
    /// Rough token estimate: chars / 4. Good enough for budget decisions.
    /// </summary>
    procedure EstimateTokens(Content: Text): Integer
    begin
        exit(StrLen(Content) div 4);
    end;

    procedure GetDefaultMaxResultChars(): Integer
    begin
        if DefaultMaxResultChars = 0 then
            DefaultMaxResultChars := 65000;
        exit(DefaultMaxResultChars);
    end;

    procedure GetDefaultMaxHistoryChars(): Integer
    begin
        if DefaultMaxHistoryChars = 0 then
            DefaultMaxHistoryChars := 80000;
        exit(DefaultMaxHistoryChars);
    end;

    procedure SetDefaults(MaxResultChars: Integer; MaxHistoryChars: Integer)
    begin
        DefaultMaxResultChars := MaxResultChars;
        DefaultMaxHistoryChars := MaxHistoryChars;
    end;

    local procedure EstimateMessageChars(MessageToken: JsonToken): Integer
    var
        MessageText: Text;
    begin
        MessageToken.WriteTo(MessageText);
        exit(StrLen(MessageText));
    end;

    local procedure GetJsonText(Source: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if Source.Get(PropertyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsText());
    end;
}
