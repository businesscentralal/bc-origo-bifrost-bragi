namespace Origo.Bifrost.LanguageModels;
using Microsoft.Sales.Document;

using Origo.Bifrost;

pageextension 10035378 "Bifrost Chat SalesRetOrder ori" extends "Sales Return Order"
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
        // Show the Anthropic Chat FactBox if the user has Anthropic Chat enabled in their setup
        ChatFactBoxVisible := BifrostChatMgt.ShowBifrostChat();
    end;

    trigger OnAfterGetCurrRecord()
    begin
        CurrPage.ori_BifrostChatFactBox.Page.SetRecordContext(Database::"Sales Header", Rec.SystemId, StrSubstNo('%1 %2', Rec."Document Type", Rec."No."));
    end;
}
