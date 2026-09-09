namespace Origo.Bifrost.Bragi;

using Origo.Bifrost;

/// <summary>
/// Adds the Bifrost Language Models action to the Bifrost Foundation setup page.
/// </summary>
pageextension 10035403 "Setup Bragi ori" extends "Setup ori"
{
    actions
    {
        addafter(UserSystemPrompts)
        {
            action(BifrostLangModels)
            {
                ApplicationArea = All;
                Caption = 'Bifrost Language Models', Comment = 'is-IS=Bifröst mállíkön';
                ToolTip = 'Manage language models with skill content injected into the Bifrost Chat.', Comment = 'is-IS=Stjórna mállíkönum með hæfniefni sem er sett inn í Spjalla við Bifröst.';
                Image = Permission;
                RunObject = page "Bifrost LangModel List ori";
            }
        }
        addafter(UserSystemPrompts_Promoted)
        {
            actionref(BifrostLangModels_Promoted; BifrostLangModels)
            {
            }
        }
    }
}
