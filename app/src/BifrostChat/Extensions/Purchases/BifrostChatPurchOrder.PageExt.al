namespace Origo.Bifrost.LanguageModels;
using Microsoft.Purchases.Document;

using Origo.Bifrost;

pageextension 10035363 "Bifrost Chat PurchOrder ori" extends "Purchase Order"
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
        CurrPage.ori_BifrostChatFactBox.Page.SetRecordContext(Database::"Purchase Header", Rec.SystemId, StrSubstNo('%1 %2', Rec."Document Type", Rec."No."));
    end;
}
