namespace Origo.Bifrost.LanguageModels;
using Microsoft.Sales.Customer;

using Origo.Bifrost;

pageextension 10035346 "Bifrost Chat CustomerCard ori" extends "Customer Card"
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
        CurrPage.ori_BifrostChatFactBox.Page.SetRecordContext(Database::Customer, Rec.SystemId, StrSubstNo('%1 %2', Rec."No.", Rec.Name));
    end;
}
