namespace Origo.Bifrost.Bragi;
using Microsoft.Sales.Receivables;

using Origo.Bifrost;

pageextension 10035349 "Bifrost Chat DtldCustLEntr ori" extends "Detailed Cust. Ledg. Entries"
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
        CurrPage.ori_BifrostChatFactBox.Page.SetRecordContext(Database::"Detailed Cust. Ledg. Entry", Rec.SystemId, StrSubstNo('%1 %2', Rec."Entry No.", Rec."Document No."));
    end;
}
