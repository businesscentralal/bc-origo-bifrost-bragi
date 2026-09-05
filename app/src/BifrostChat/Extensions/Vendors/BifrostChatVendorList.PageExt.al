namespace Origo.Bifrost.Bragi;
using Microsoft.Purchases.Vendor;

using Origo.Bifrost;

pageextension 10035381 "Bifrost Chat VendorList ori" extends "Vendor List"
{
    ContextSensitiveHelpPage = 'BifrostChat.html';
    actions
    {
        addlast(Processing)
        {
            action(ori_BifrostChat)
            {
                Caption = 'Bifrost Chat', Comment = 'is-IS=Spjalla við Bifröst';
                ToolTip = 'Chat about this vendor in Business Central.', Comment = 'is-IS=Spjalla um þennan lánardrottin í Business Central';
                ApplicationArea = All;
                Visible = ChatBoxVisible;
                Image = SparkleFilled;

                trigger OnAction()
                var
                    BifrostChatFocus: Page "Chat Focus ori";
                begin
                    BifrostChatFocus.SetRecordContext(Database::Vendor, Rec.SystemId, StrSubstNo('%1 %2', Rec."No.", Rec.Name));
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
