namespace Origo.Bifrost.Bragi;
using Origo.Bifrost;

using System.Environment;
using System.Reflection;

/// <summary>
/// FactBox hosting the provider-neutral "Bifrost Chat ori" control add-in.
/// All backend communication is routed through "Bifrost Chat Mgt ori" so this page
/// has no compile-time dependency on any specific chat provider.
/// </summary>
page 10035341 "Bifrost Chat FactBox ori"
{
    Caption = 'Bifrost Chat', Comment = 'is-IS=Spjalla við Bifröst';
    PageType = CardPart;
    RefreshOnActivate = true;
    DataCaptionExpression = DataCaptionText;

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

    actions
    {
        area(Processing)
        {
            action(Focus)
            {
                Caption = 'Focus', Comment = 'is-IS=Fókus';
                ToolTip = 'Open the chat in a full-page view.', Comment = 'is-IS=Opna spjallið á heilsíðu.';
                ApplicationArea = All;
                Image = View;

                trigger OnAction()
                begin
                    FocusRequested := true;
                    CurrPage.BifrostChat.RequestChatHistory();
                end;
            }
            action(UserSetup)
            {
                Caption = 'User Setup', Comment = 'is-IS=Notandauppsetning';
                ToolTip = 'Open the Bifrost user setup for the current user.', Comment = 'is-IS=Opna notandauppsetningu Bifröst fyrir núverandi notanda.';
                ApplicationArea = All;
                Image = UserSetup;
                RunObject = page "User Setup Editor ori";
            }
        }
    }

    var
        PendingTableId: Integer;
        PendingRecordSystemId: Guid;
        DataCaptionText: Text;
        PendingContextSkill: Text;
        IsControlReady: Boolean;
        FocusRequested: Boolean;

    /// <summary>
    /// Sets the record context for the chat so it can query BC data via Data.Records.Get.
    /// Call this from the hosting page when the source record changes.
    /// </summary>
    /// <param name="TableId">The table number of the current record.</param>
    /// <param name="RecordSystemId">The SystemId (GUID) of the current record.</param>
    /// <param name="DataCaption">Text displayed as the page DataCaptionExpression.</param>
    procedure SetRecordContext(TableId: Integer; RecordSystemId: Guid; DataCaption: Text)
    begin
        SetRecordContextWithSkill(TableId, RecordSystemId, DataCaption, '');
    end;

    /// <summary>
    /// Sets the record context and optional context-specific skill for the chat.
    /// The context skill is appended to the prompt in addition to the user's role skill.
    /// </summary>
    /// <param name="TableId">The table number of the current record.</param>
    /// <param name="RecordSystemId">The SystemId (GUID) of the current record.</param>
    /// <param name="DataCaption">Text displayed as the page DataCaptionExpression.</param>
    /// <param name="ContextSkill">Additional markdown guidance specific to this record context.</param>
    procedure SetRecordContextWithSkill(TableId: Integer; RecordSystemId: Guid; DataCaption: Text; ContextSkill: Text)
    begin
        PendingTableId := TableId;
        PendingRecordSystemId := RecordSystemId;
        DataCaptionText := DataCaption;
        PendingContextSkill := ContextSkill;
        if not IsControlReady then
            exit;
        CurrPage.BifrostChat.SetRecordContext(PendingTableId, Format(PendingRecordSystemId, 0, 4), GetTableName(PendingTableId), DataCaptionText);
        CurrPage.BifrostChat.SetContextSkill(PendingContextSkill);
    end;

    local procedure InitializeChat()
    var
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
        ToolServer: Codeunit "MCP Tool Server ori";
        ConfigJson: Text;
    begin
        IsControlReady := true;
        ToolServer.ClearSession();

        ConfigJson := BifrostChatMgt.BuildConfigJson();
        CurrPage.BifrostChat.Initialize(ConfigJson);

        if PendingTableId <> 0 then begin
            CurrPage.BifrostChat.SetRecordContext(PendingTableId, Format(PendingRecordSystemId, 0, 4), GetTableName(PendingTableId), DataCaptionText);
            CurrPage.BifrostChat.SetContextSkill(PendingContextSkill);
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
        if not FocusRequested then
            exit;
        FocusRequested := false;

        BifrostChatTransfer.SetContext(PendingTableId, PendingRecordSystemId, HistoryJson);
        BifrostChatTransfer.SetDataCaption(DataCaptionText);
        BifrostChatTransfer.SetContextSkill(PendingContextSkill);
        Page.RunModal(Page::"Chat Focus ori");

        if BifrostChatTransfer.HasData() then begin
            CurrPage.BifrostChat.RestoreChatHistory(BifrostChatTransfer.GetHistoryJson());
            BifrostChatTransfer.Clear();
        end;
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
