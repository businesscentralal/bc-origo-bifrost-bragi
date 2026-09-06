namespace Origo.Bifrost.LanguageModels.Test;
using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;

/// <summary>
/// Registers the Mock provider on the "Bifrost LangModel Prov. ori" enum
/// so dispatcher tests can route through the "Mock Bifrost Chat Provider" codeunit.
/// </summary>
enumextension 96000 "Mock Bifrost LangModel Prov." extends "Bifrost LangModel Prov. ori"
{
    value(96000; Mock)
    {
        Caption = 'Mock', Comment = 'is-IS=Mock';
        Implementation = "Bifrost LangModel Provider ori" = "Mock Bifrost Chat Provider";
    }
}
