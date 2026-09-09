namespace Origo.Bifrost.LanguageModels;
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
    value(2; OpenAI)
    {
        Caption = 'OpenAI', Comment = 'is-IS=OpenAI';
        Implementation = "Bifrost LangModel Provider ori" = "OpenAI LangModel Prov. ori";
    }
    value(3; "Azure OpenAI")
    {
        Caption = 'Azure OpenAI', Comment = 'is-IS=Azure OpenAI';
        Implementation = "Bifrost LangModel Provider ori" = "Azure OAI LangModel Prov. ori";
    }
    value(4; "Custom LLM")
    {
        Caption = 'Custom LLM', Comment = 'is-IS=Sérsniðið LLM';
        Implementation = "Bifrost LangModel Provider ori" = "Custom LLM LangModel Prov. ori";
    }
    value(5; Anthropic)
    {
        Caption = 'Anthropic', Comment = 'is-IS=Anthropic';
        Implementation = "Bifrost LangModel Provider ori" = "Anthropic LangModel Prov. ori";
    }
    value(6; "xAI")
    {
        Caption = 'xAI (Grok)', Comment = 'is-IS=xAI (Grok)';
        Implementation = "Bifrost LangModel Provider ori" = "xAI LangModel Prov. ori";
    }
    value(7; Google)
    {
        Caption = 'Google (Gemini)', Comment = 'is-IS=Google (Gemini)';
        Implementation = "Bifrost LangModel Provider ori" = "Gemini LangModel Prov. ori";
    }
}
