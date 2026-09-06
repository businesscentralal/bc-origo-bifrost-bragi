namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

/// <summary>
/// Read-only access to Bifrost Language Models. Language models can be inspected but not changed.
/// Assign "BIFROST Chat ori" on top of this set to let a user open a chat.
/// The set deliberately does not grant the "App Secrets ori" page: that is the administrator's
/// surface over Foundation's secret store and is already covered by "BIFROST Read ori" and
/// "BIFROST Full ori", which also grant the underlying "App Secret ori" table data.
/// </summary>
permissionset 10035405 "BIFROST LLM Rd ori"
{
    Assignable = true;
    Caption = 'Bifrost Language Models Read', MaxLength = 30, Comment = 'is-IS=Bifröst mállíkön lestur';

    Permissions =
        table "Bifrost Language Model ori" = X,
        tabledata "Bifrost Language Model ori" = R,
        table "Chat Gate ori" = X,
        tabledata "Chat Gate ori" = R,
        table "Bifrost Chat Argument ori" = X,
        // RIMD, not R: "Bifrost Chat Argument ori" is TableType = Temporary — the in-memory DTO of
        // the provider interface. Every provider writes its output fields back into the record the
        // caller passed in, so read-only users need the same insert/modify rights on it as anyone
        // else. No row ever reaches the database.
        tabledata "Bifrost Chat Argument ori" = RIMD,
        page "Bifrost Chat FactBox ori" = X,
        page "Bifrost Chat Model List ori" = X,
        page "Bifrost LangModel Card ori" = X,
        page "Bifrost LangModel List ori" = X,
        page "LangModel Setup ori" = X,
        page "Chat Focus ori" = X,
        codeunit "Bifrost Chat Mgt ori" = X,
        codeunit "LangModel Secrets ori" = X,
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
