namespace Origo.Bifrost.Bragi.Test;

using Origo.Bifrost;

/// <summary>
/// Registers the Bragi.Mock.Get message type so the MCP tool server tests can toggle
/// a message type on and off without touching a shipped type.
/// </summary>
enumextension 96008 "Bragi Mock Message Type" extends "Message Type ori"
{
    value(96008; "Bragi.Mock.Get")
    {
        Caption = 'Bragi Mock Get', Locked = true;
        Implementation = "Msg Interface ori" = "Bragi Mock Get Msg Co";
    }
}
