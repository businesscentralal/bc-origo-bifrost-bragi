namespace Origo.Bifrost.LanguageModels;

using Origo.Bifrost;

/// <summary>
/// Adds the language model assignment and the Bifrost Chat FactBox to the
/// Bifrost Foundation user setup editor.
/// </summary>
pageextension 10035402 "User Setup Editor LangMdl ori" extends "User Setup Editor ori"
{
    layout
    {
        addlast(LinkedRecords)
        {
            field("Bifrost Language Model Code"; Rec."Bifrost Language Model Code")
            {
                ApplicationArea = All;
                Caption = 'Language Model Code', Comment = 'is-IS=Kóði mállíkans';
                ToolTip = 'Specifies the language model whose skill is injected into Chat via Bifrost. If empty, a default who_am_i instruction is used.', Comment = 'is-IS=Tilgreinir mállíkanið sem hæfni er sótt úr fyrir Spjalla með Bifröst. Ef tómt eru sjálfgefnar who_am_i leiðbeiningar notaðar.';

                trigger OnValidate()
                begin
                    CurrPage.Update(true);
                end;
            }
        }
        addlast(FactBoxes)
        {
            part(ori_BifrostChatFactBox; "Bifrost Chat FactBox ori")
            {
                ApplicationArea = All;
            }
        }
    }

    trigger OnAfterGetCurrRecord()
    begin
        CurrPage.ori_BifrostChatFactBox.Page.SetRecordContext(Database::"User Setup ori", Rec.SystemId, StrSubstNo(ChatContextCaptionLbl, Rec.TableCaption(), Rec."User Name"));
    end;

    var
        ChatContextCaptionLbl: Label '%1 %2', Locked = true;
}
