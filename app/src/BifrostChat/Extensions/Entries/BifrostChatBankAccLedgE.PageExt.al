namespace Origo.Bifrost.Bragi;
using Microsoft.Bank.Ledger;

using Origo.Bifrost;

pageextension 10035348 "Bifrost Chat BankAccLedgE ori" extends "Bank Account Ledger Entries"
{
    ContextSensitiveHelpPage = 'BifrostChat.html';
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
        CurrPage.ori_BifrostChatFactBox.Page.SetRecordContext(Database::"Bank Account Ledger Entry", Rec.SystemId, StrSubstNo('%1 %2', Rec."Entry No.", Rec.Description));
    end;
}
