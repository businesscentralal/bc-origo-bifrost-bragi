namespace Origo.Bifrost.Bragi;
using Origo.Bifrost;

/// <summary>
/// Read-only access to Bifrost Bragi. Language models can be inspected but not changed.
/// Assign "BIFROST Chat ori" on top of this set to let a user open a chat.
/// </summary>
permissionset 10035405 "BIFROST Bragi Rd ori"
{
    Assignable = true;
    Caption = 'Bifrost Bragi Read', MaxLength = 30, Comment = 'is-IS=Bifröst Bragi lestur';

    Permissions =
        table "Bifrost Language Model ori" = X,
        tabledata "Bifrost Language Model ori" = R,
        table "Chat Gate ori" = X,
        tabledata "Chat Gate ori" = R,
        table "Bifrost Chat Argument ori" = X,
        tabledata "Bifrost Chat Argument ori" = RIMD,
        page "Bifrost Chat FactBox ori" = X,
        page "Bifrost Chat Model List ori" = X,
        page "Bifrost LangModel Card ori" = X,
        page "Bifrost LangModel List ori" = X,
        page "App Secrets ori" = X,
        page "Bragi Setup ori" = X,
        page "Chat Focus ori" = X,
        codeunit "Bifrost Chat Mgt ori" = X,
        codeunit "Bragi Secrets ori" = X,
        codeunit "Secret Store ori" = X,
        codeunit "Bifrost Chat Transfer ori" = X,
        codeunit "Bifrost Chat Utils ori" = X,
        codeunit "Bifrost LangModel None ori" = X,
        codeunit "Bifrost LangModel Test Ctx ori" = X,
        codeunit "Copilot AOAI Func Impl ori" = X,
        codeunit "Copilot Chat Proxy ori" = X,
        codeunit "Copilot Default Skill ori" = X,
        codeunit "Copilot LangModel Prov. ori" = X,
        codeunit "Copilot Req Log Masker ori" = X,
        codeunit "LLM Prompt Compl Help ori" = X,
        codeunit "LLM Prompt Compl Impl ori" = X,
        codeunit "MCP Tool Executor ori" = X,
        codeunit "MCP Tool Server ori" = X;
}
