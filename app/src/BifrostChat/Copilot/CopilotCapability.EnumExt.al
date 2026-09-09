namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

using System.AI;

/// <summary>
/// Registers the Bifrost Chat capability on the Copilot Capability enum.
/// </summary>
enumextension 10035340 "Copilot Capability ori" extends "Copilot Capability"
{
    value(10035340; "Bifrost Chat ori")
    {
        Caption = 'Bifrost Copilot', Comment = 'is-IS=Bifröst Copilot';
    }
}
