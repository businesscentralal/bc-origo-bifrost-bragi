namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

/// <summary>
/// Full access to Bifrost Language Models: the Bifrost Chat, language models, the Copilot provider,
/// the MCP tool server and the LLM.Prompt.Complete message type.
/// Write access to the Chat Gate is deliberately excluded — assign "BIFROST Chat ori"
/// on top of this set to let a user actually open a chat.
/// </summary>
permissionset 10035404 "BIFROST LLM ori"
{
    Assignable = true;
    Caption = 'Bifrost Language Models', MaxLength = 30, Comment = 'is-IS=Bifröst mállíkön';

    Permissions =
        table "Bifrost Language Model ori" = X,
        tabledata "Bifrost Language Model ori" = RIMD,
        table "Chat Gate ori" = X,
        tabledata "Chat Gate ori" = R,
        table "Bifrost Chat Argument ori" = X,
        // RIMD, not R: "Bifrost Chat Argument ori" is TableType = Temporary — the in-memory DTO of
        // the provider interface. Every provider writes its output fields back into the record the
        // caller passed in. No row ever reaches the database.
        tabledata "Bifrost Chat Argument ori" = RIMD,
        page "Bifrost Chat FactBox ori" = X,
        page "Bifrost Chat Model List ori" = X,
        page "Bifrost LangModel Card ori" = X,
        page "Bifrost LangModel List ori" = X,
        page "App Secrets ori" = X,
        page "LangModel Setup ori" = X,
        page "Chat Focus ori" = X,
        codeunit "Bifrost Chat Mgt ori" = X,
        codeunit "LangModel Secrets ori" = X,
        codeunit "Secret Store ori" = X,
        codeunit "Bifrost Chat Transfer ori" = X,
        codeunit "Bifrost Chat Utils ori" = X,
        codeunit "Bifrost LangModel None ori" = X,
        codeunit "Bifrost LangModel Test Ctx ori" = X,
        codeunit "Chat Providers Install ori" = X,
        codeunit "Copilot AOAI Func Impl ori" = X,
        codeunit "Copilot Chat Proxy ori" = X,
        codeunit "Copilot Default Skill ori" = X,
        codeunit "Copilot Install ori" = X,
        codeunit "Copilot LangModel Prov. ori" = X,
        codeunit "Copilot Req Log Masker ori" = X,
        codeunit "Copilot Upgrade ori" = X,
        codeunit "LLM Prompt Compl Help ori" = X,
        codeunit "LLM Prompt Compl Impl ori" = X,
        codeunit "MCP Tool Executor ori" = X,
        codeunit "MCP Tool Server ori" = X;
}
