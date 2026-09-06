namespace Origo.Bifrost.Bragi;
using Microsoft.Sales.Receivables;

using Origo.Bifrost;

pageextension 10035350 "Bifrost Chat CustLedgEntr ori" extends "Customer Ledger Entries"
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
        CurrPage.ori_BifrostChatFactBox.Page.SetRecordContext(Database::"Cust. Ledger Entry", Rec.SystemId, StrSubstNo('%1 %2', Rec."Entry No.", Rec.Description));
    end;
}
