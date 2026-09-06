namespace Origo.Bifrost.LanguageModels;
using Microsoft.Purchases.Payables;

using Origo.Bifrost;

pageextension 10035355 "Bifrost Chat VendLedgEntr ori" extends "Vendor Ledger Entries"
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
        CurrPage.ori_BifrostChatFactBox.Page.SetRecordContext(Database::"Vendor Ledger Entry", Rec.SystemId, StrSubstNo('%1 %2', Rec."Entry No.", Rec.Description));
    end;
}
