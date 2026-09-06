namespace Origo.Bifrost.LanguageModels;
using Microsoft.EServices.EDocument;

using Origo.Bifrost;

pageextension 10035356 "Bifrost Chat IncomingDocs ori" extends "Incoming Documents"
{
    ContextSensitiveHelpPage = 'bifrost-chat';
    actions
    {
        addlast(Processing)
        {
            action(ori_BifrostChat)
            {
                Caption = 'Bifrost Chat', Comment = 'is-IS=Spjalla við Bifröst';
                ToolTip = 'Chat about this incoming document in Business Central.', Comment = 'is-IS=Spjalla um þetta skjal á innleið í Business Central';
                ApplicationArea = All;
                Visible = ChatBoxVisible;
                Image = SparkleFilled;

                trigger OnAction()
                var
                    BifrostChatFocus: Page "Chat Focus ori";
                begin
                    BifrostChatFocus.SetRecordContext(Database::"Incoming Document", Rec.SystemId, StrSubstNo('%1 %2', Rec.TableCaption(), Rec."Entry No."));
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
