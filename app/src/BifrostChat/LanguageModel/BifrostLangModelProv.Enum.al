namespace Origo.Bifrost.Bragi;
using Origo.Bifrost;

/// <summary>
/// Selects the chat provider for a Bifrost Language Model.
/// When set to None, the language model inherits the user-level provider.
/// Extensible so provider extensions can register language-model overrides.
/// </summary>
enum 10035339 "Bifrost LangModel Prov. ori" implements "Bifrost LangModel Provider ori"
{
    Access = Public;
    Extensible = true;
    DefaultImplementation = "Bifrost LangModel Provider ori" = "Bifrost LangModel None ori";

    value(0; None)
    {
        Caption = 'None', Comment = 'is-IS=Enginn';
        Implementation = "Bifrost LangModel Provider ori" = "Bifrost LangModel None ori";
    }
    value(1; Copilot)
    {
        Caption = 'Copilot', Comment = 'is-IS=Copilot';
        Implementation = "Bifrost LangModel Provider ori" = "Copilot LangModel Prov. ori";
    }
}
