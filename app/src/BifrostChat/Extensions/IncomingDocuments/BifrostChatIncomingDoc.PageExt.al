namespace Origo.Bifrost.LanguageModels;
using Microsoft.EServices.EDocument;

using Origo.Bifrost;

pageextension 10035357 "Bifrost Chat IncomingDoc ori" extends "Incoming Document"
{
    ContextSensitiveHelpPage = 'bifrost-chat';
    layout
    {
        addfirst(factboxes)
        {
            part(ori_BifrostChatFactBox; "Bifrost Chat FactBox ori")
            {
                ApplicationArea = All;
                Visible = ChatFactBoxVisible;
            }
        }
    }
    var
        ChatFactBoxVisible: Boolean;

    trigger OnOpenPage()
    var
        BifrostChatMgt: Codeunit "Bifrost Chat Mgt ori";
    begin
        ChatFactBoxVisible := BifrostChatMgt.ShowBifrostChat();
    end;

    trigger OnAfterGetCurrRecord()
    begin
        CurrPage.ori_BifrostChatFactBox.Page.SetRecordContext(Database::"Incoming Document", Rec.SystemId, StrSubstNo('%1 %2', Rec.TableCaption(), Rec."Entry No."));
    end;
}
