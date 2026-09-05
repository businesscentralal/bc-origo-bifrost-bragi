namespace Origo.Bifrost.Bragi;
using Origo.Bifrost;

using System.Environment;
using System.Reflection;

/// <summary>
/// Full-page Bifrost Chat interface opened from the FactBox "Focus" action.
/// Restores chat history and record context from the transfer codeunit and
/// routes all backend calls through "Bifrost Chat Mgt ori".
/// </summary>
page 10035345 "Chat Focus ori"
{
    Caption = 'Bifrost Chat', Comment = 'is-IS=Spjalla við Bifröst';
    PageType = UserControlHost;
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            usercontrol(BifrostChat; "Bifrost Chat ori")
            {
                ApplicationArea = All;

                trigger ControlReady()
                begin
                    InitializeChat();
                end;

                trigger MessageSubmitted(UserMessage: Text)
                begin
                end;

                trigger SubmitChatMessage(PayloadJson: Text)
                begin
                    HandleSubmitChatMessage(PayloadJson);
                end;

                trigger SaveApiKey(ApiKey: Text)
                var
                    BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
                begin
                    BifrostChatMgt.SaveApiKey(ApiKey);
                end;

                trigger SaveServiceApiKey(ApiKey: Text)
                var
                    BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
                begin
                    BifrostChatMgt.SaveServiceApiKey(ApiKey);
                end;

                trigger ChatHistoryReady(HistoryJson: Text)
                begin
                    HandleChatHistoryReady(HistoryJson);
                end;

                trigger ValidateConnection()
                begin
                    HandleValidateConnection();
                end;

                trigger ExecuteToolCall(ToolCallId: Text; ToolName: Text; ArgumentsJson: Text)
                begin
                    HandleExecuteToolCall(ToolCallId, ToolName, ArgumentsJson);
                end;

                trigger ContinueWithToolResults(ConversationState: Text; ToolResultsJson: Text)
                begin
                    HandleContinueWithToolResults(ConversationState, ToolResultsJson);
                end;

                trigger RecordContextChanged()
                var
                    ToolServer: Codeunit "MCP Tool Server ori";
                begin
                    ToolServer.ClearSession();
                end;
            }
        }
    }

    var
        ReturnRequested: Boolean;
        ContextTableId: Integer;
        ContextRecordSystemId: Guid;
        DataCaptionText: Text;
        ContextSkillText: Text;

    /// <summary>
    /// Sets the record context for the chat.
    /// </summary>
    /// <param name="TableId">The table number of the current record.</param>
    /// <param name="RecordSystemId">The SystemId of the current record.</param>
    /// <param name="DataCaption">Caption text shown above the chat area.</param>
    procedure SetRecordContext(TableId: Integer; RecordSystemId: Guid; DataCaption: Text)
    begin
        SetRecordContextWithSkill(TableId, RecordSystemId, DataCaption, '');
    end;

    /// <summary>
    /// Sets the record context and optional context-specific skill for the chat.
    /// </summary>
    /// <param name="TableId">The table number of the current record.</param>
    /// <param name="RecordSystemId">The SystemId of the current record.</param>
    /// <param name="DataCaption">Caption text shown above the chat area.</param>
    /// <param name="ContextSkill">Additional markdown guidance for this context.</param>
    procedure SetRecordContextWithSkill(TableId: Integer; RecordSystemId: Guid; DataCaption: Text; ContextSkill: Text)
    begin
        ContextTableId := TableId;
        ContextRecordSystemId := RecordSystemId;
        DataCaptionText := DataCaption;
        ContextSkillText := ContextSkill;
    end;

    local procedure InitializeChat()
    var
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
        BifrostChatTransfer: Codeunit "Bifrost Chat Transfer ori";
        ToolServer: Codeunit "MCP Tool Server ori";
        ConfigJson: Text;
    begin
        ToolServer.ClearSession();
        ConfigJson := BifrostChatMgt.BuildConfigJson();
        CurrPage.BifrostChat.Initialize(ConfigJson);

        if BifrostChatTransfer.HasData() then begin
            ContextTableId := BifrostChatTransfer.GetTableId();
            ContextRecordSystemId := BifrostChatTransfer.GetRecordSystemId();
            DataCaptionText := BifrostChatTransfer.GetDataCaption();
            ContextSkillText := BifrostChatTransfer.GetContextSkill();
            CurrPage.BifrostChat.SetRecordContext(ContextTableId, Format(ContextRecordSystemId, 0, 4), GetTableName(ContextTableId), DataCaptionText);
            CurrPage.BifrostChat.SetContextSkill(ContextSkillText);
            CurrPage.BifrostChat.RestoreChatHistory(BifrostChatTransfer.GetHistoryJson());
            BifrostChatTransfer.Clear();
        end else
            if ContextTableId <> 0 then begin
                CurrPage.BifrostChat.SetRecordContext(ContextTableId, Format(ContextRecordSystemId, 0, 4), GetTableName(ContextTableId), DataCaptionText);
                CurrPage.BifrostChat.SetContextSkill(ContextSkillText);
            end;
    end;

    local procedure GetTableName(TableId: Integer): Text
    var
        AllObjWithCaption: Record AllObjWithCaption;
    begin
        AllObjWithCaption.SetRange("Object Type", AllObjWithCaption."Object Type"::Table);
        AllObjWithCaption.SetRange("Object ID", TableId);
        AllObjWithCaption.SetLoadFields("Object Caption");
        if AllObjWithCaption.FindFirst() then
            exit(AllObjWithCaption."Object Caption");
    end;

    local procedure HandleSubmitChatMessage(PayloadJson: Text)
    var
        ResponseJson: Text;
    begin
        ResponseJson := SendChatMessageSafe(PayloadJson);
        CurrPage.BifrostChat.ChatMessageResult(ResponseJson);
    end;

    local procedure SendChatMessageSafe(PayloadJson: Text): Text
    var
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
    begin
        exit(BifrostChatMgt.SendChatMessage(PayloadJson));
    end;

    local procedure HandleExecuteToolCall(ToolCallId: Text; ToolName: Text; ArgumentsJson: Text)
    var
        ToolServer: Codeunit "MCP Tool Server ori";
        Arguments: JsonObject;
        ResultJson: JsonObject;
        ResultText: Text;
        IsError: Boolean;
    begin
        Arguments.ReadFrom(ArgumentsJson);
        ToolServer.CallTool(ToolName, Arguments, ResultText, IsError);
        ResultJson.Add('id', ToolCallId);
        ResultJson.Add('name', ToolName);
        ResultJson.Add('result', ResultText);
        ResultJson.Add('isError', IsError);
        CurrPage.BifrostChat.ToolCallResult(Format(ResultJson));
    end;

    local procedure HandleContinueWithToolResults(ConversationState: Text; ToolResultsJson: Text)
    var
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
        ResponseJson: Text;
    begin
        ResponseJson := BifrostChatMgt.ContinueWithToolResults(ConversationState, ToolResultsJson);
        CurrPage.BifrostChat.ChatMessageResult(ResponseJson);
    end;

    local procedure HandleChatHistoryReady(HistoryJson: Text)
    var
        BifrostChatTransfer: Codeunit "Bifrost Chat Transfer ori";
    begin
        BifrostChatTransfer.SetContext(ContextTableId, ContextRecordSystemId, HistoryJson);
        BifrostChatTransfer.SetDataCaption(DataCaptionText);
        BifrostChatTransfer.SetContextSkill(ContextSkillText);
        if ReturnRequested then
            CurrPage.Close();
    end;

    local procedure HandleValidateConnection()
    var
        Company: Record Company;
        BifrostChatUtils: Codeunit "Bifrost Chat Utils ori";
        ResponseJson: JsonObject;
        IdentityJson: JsonObject;
        CompaniesArray: JsonArray;
        CompanyJson: JsonObject;
        IdentityToken: JsonToken;
        IdentityKey: Text;
    begin
        Company.SetLoadFields(Name, "Display Name");
        if Company.FindSet() then
            repeat
                Clear(CompanyJson);
                CompanyJson.Add('name', Company.Name);
                CompanyJson.Add('displayName', Company."Display Name");
                CompaniesArray.Add(CompanyJson);
            until Company.Next() = 0;

        ResponseJson.Add('companies', CompaniesArray);
        ResponseJson.Add('currentCompany', CompanyName());

        IdentityJson := BifrostChatUtils.GetIdentityJson();
        foreach IdentityKey in IdentityJson.Keys() do begin
            IdentityJson.Get(IdentityKey, IdentityToken);
            ResponseJson.Add(IdentityKey, IdentityToken);
        end;

        CurrPage.BifrostChat.ConnectionValidated(Format(ResponseJson));
    end;
}
