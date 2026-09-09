namespace Origo.Bifrost.LanguageModels;

using Origo.Bifrost;

/// <summary>
/// Adds Bifrost Language Models to the Apps group of the Bifrost Foundation setup page.
/// Foundation owns the setup page; Bifrost Language Models contributes exactly one action, which opens
/// the "LangModel Setup ori" page where all its settings live.
/// </summary>
pageextension 10035403 "Setup LangModel ori" extends "Setup ori"
{
    actions
    {
        addlast(Apps)
        {
            action(LangModelSetup)
            {
                ApplicationArea = All;
                Caption = 'Bifrost Language Models Setup', Comment = 'is-IS=Uppsetning Bifröst mállíkana';
                ToolTip = 'Open the setup page of Bifrost Language Models, with the models, the MCP tool server and the provider API keys.', Comment = 'is-IS=Opna uppsetningarsíðu Bifröst mállíkana, með líkönunum, MCP verkfæraþjóni og API-lyklum veitenda.';
                Image = Setup;
                RunObject = page "LangModel Setup ori";
            }
        }
        addlast(Category_Apps)
        {
            actionref(LangModelSetup_Promoted; LangModelSetup)
            {
            }
        }
    }
}
