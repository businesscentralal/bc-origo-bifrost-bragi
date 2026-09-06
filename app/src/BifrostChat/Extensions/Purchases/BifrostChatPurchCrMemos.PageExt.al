namespace Origo.Bifrost.Bragi;
using Microsoft.Purchases.Document;

using Origo.Bifrost;

pageextension 10035361 "Bifrost Chat PurchCrMemos ori" extends "Purchase Credit Memos"
{
    ContextSensitiveHelpPage = 'bifrost-chat';
    actions
    {
        addlast(Processing)
        {
            action(ori_BifrostChat)
            {
                Caption = 'Bifrost Chat', Comment = 'is-IS=Spjalla við Bifröst';
                ToolTip = 'Chat about this credit memo in Business Central.', Comment = 'is-IS=Spjalla um þessa kreditnótu í Business Central';
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
