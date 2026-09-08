namespace Origo.Bifrost.LanguageModels;
using Microsoft.Purchases.Document;

using Origo.Bifrost;

pageextension 10035369 "Bifrost Chat PurchRetOrds ori" extends "Purchase Return Orders"
{
    ContextSensitiveHelpPage = 'bifrost-chat';
    actions
    {
        addlast(Processing)
        {
            action(ori_BifrostChat)
            {
                Caption = 'Chat via Bifrost', Comment = 'is-IS=Spjalla með Bifröst';
                ToolTip = 'Chat about this return order in Business Central.', Comment = 'is-IS=Spjalla um þessa vöruskilapöntun í Business Central';
                ApplicationArea = All;
                Visible = ChatBoxVisible;
                Image = SparkleFilled;

                trigger OnAction()
                var
                    BifrostChatFocus: Page "Chat Focus ori";
                begin
                    BifrostChatFocus.SetRecordContext(Database::"Purchase Header", Rec.SystemId, StrSubstNo('%1 %2', Rec."Document Type", Rec."No."));
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
