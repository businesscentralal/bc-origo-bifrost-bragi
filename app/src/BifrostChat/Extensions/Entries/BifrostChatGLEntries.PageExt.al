namespace Origo.Bifrost.Bragi;
using Microsoft.Finance.GeneralLedger.Ledger;

using Origo.Bifrost;

pageextension 10035351 "Bifrost Chat GLEntries ori" extends "General Ledger Entries"
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
        CurrPage.ori_BifrostChatFactBox.Page.SetRecordContext(Database::"G/L Entry", Rec.SystemId, StrSubstNo('%1 %2', Rec."Entry No.", Rec.Description));
    end;
}
