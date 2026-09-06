namespace Origo.Bifrost.Bragi;
using Origo.Bifrost;

/// <summary>
/// Grants Bifrost Chat capability.
/// Users with this permission set may use the Bifrost Chat FactBox/Focus page,
/// invoke LLM.Prompt.Complete via the API, and execute any of the registered
/// chat provider codeunits (Copilot, OpenAI, Azure OpenAI, Custom LLM, Anthropic,
/// xAI, Google/Gemini).
/// Not bundled into Bifrost Read or Bifrost Full — administrators must assign explicitly.
/// </summary>
permissionset 10035398 "BIFROST Chat ori"
{
    Assignable = true;
    Caption = 'Chat Gate', MaxLength = 30, Comment = 'is-IS=Spjallhlið';

    Permissions =
        tabledata "Chat Gate ori" = RIMD,
        codeunit "Bragi Secrets ori" = X,
        codeunit "Secret Store ori" = X,
        codeunit "LangModel Prov. Base ori" = X,
        codeunit "LangModel API Client ori" = X,
        codeunit "LangModel Chat Proxy ori" = X,
        codeunit "Anthropic LangModel Proxy ori" = X,
        codeunit "OpenAI LangModel Prov. ori" = X,
        codeunit "Azure OAI LangModel Prov. ori" = X,
        codeunit "Custom LLM LangModel Prov. ori" = X,
        codeunit "Anthropic LangModel Prov. ori" = X,
        codeunit "xAI LangModel Prov. ori" = X,
        codeunit "Gemini LangModel Prov. ori" = X,
        codeunit "Chat Http Notif. Action ori" = X,
        codeunit "LLM Req Log Masker ori" = X;
}
