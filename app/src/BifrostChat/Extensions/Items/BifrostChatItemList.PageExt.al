namespace Origo.Bifrost.LanguageModels;
using Microsoft.Inventory.Item;

using Origo.Bifrost;

pageextension 10035359 "Bifrost Chat ItemList ori" extends "Item List"
{
    ContextSensitiveHelpPage = 'bifrost-chat';
    actions
    {
        addlast(Processing)
        {
            action(ori_BifrostChat)
            {
                Caption = 'Chat via Bifrost', Comment = 'is-IS=Spjalla með Bifröst';
                ToolTip = 'Chat about this item in Business Central.', Comment = 'is-IS=Spjalla um þessa vöru í Business Central';
                ApplicationArea = All;
                Visible = ChatBoxVisible;
                Image = SparkleFilled;

                trigger OnAction()
                var
                    BifrostChatFocus: Page "Chat Focus ori";
                begin
                    BifrostChatFocus.SetRecordContext(Database::Item, Rec.SystemId, StrSubstNo('%1 %2', Rec."No.", Rec.Description));
                    BifrostChatFocus.Run();
                end;
            }
        }
        addlast(Category_Process)
        {
            actionref(ori_BifrostChat_Promoted; ori_BifrostChat)
            {
            }
        }
    }

    var
        ChatBoxVisible: Boolean;

    trigger OnOpenPage()
    var
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
    begin
        ChatBoxVisible := BifrostChatMgt.ShowBifrostChat();
    end;
}
