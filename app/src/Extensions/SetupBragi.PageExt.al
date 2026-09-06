namespace Origo.Bifrost.Bragi;

using Origo.Bifrost;

/// <summary>
/// Adds Bifrost Bragi to the Apps group of the Bifrost Foundation setup page.
/// Foundation owns the setup page; Bragi contributes exactly one action, which opens
/// the "Bragi Setup ori" page where all Bragi settings live.
/// </summary>
pageextension 10035403 "Setup Bragi ori" extends "Setup ori"
{
    actions
    {
        addlast(Apps)
        {
            action(BragiSetup)
            {
                ApplicationArea = All;
                Caption = 'Bifrost Bragi Setup', Comment = 'is-IS=Uppsetning Bifröst Braga';
                ToolTip = 'Open the setup page of Bifrost Bragi, with the language models, the MCP tool server and the provider API keys.', Comment = 'is-IS=Opna uppsetningarsíðu Bifröst Braga, með mállíkönum, MCP verkfæraþjóni og API-lyklum veitenda.';
                Image = Setup;
                RunObject = page "Bragi Setup ori";
            }
        }
        addlast(Category_Apps)
        {
            actionref(BragiSetup_Promoted; BragiSetup)
            {
            }
        }
    }
}
