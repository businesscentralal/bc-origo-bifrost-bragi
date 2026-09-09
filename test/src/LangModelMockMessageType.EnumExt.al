namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;

/// <summary>
/// Registers the LangModel.Mock.Get message type so the MCP tool server tests can toggle
/// a message type on and off without touching a shipped type.
/// </summary>
enumextension 96008 "LangModel Mock Message Type" extends "Message Type ori"
{
    value(96008; "LangModel.Mock.Get")
    {
        Caption = 'LangModel Mock Get', Locked = true;
        Implementation = "Msg Interface ori" = "LangModel Mock Get Msg Co";
    }
}
