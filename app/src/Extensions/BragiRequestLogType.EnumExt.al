namespace Origo.Bifrost.Bragi;

using Origo.Bifrost;

/// <summary>
/// Registers the Copilot request log type on the Bifrost Foundation request log type enum,
/// together with the masker that redacts Copilot secrets before the request is stored.
/// </summary>
enumextension 10035400 "Bragi Request Log Type ori" extends "Request Log Type ori"
{
    /// <summary>
    /// Requests sent to the Microsoft Copilot / Azure OpenAI endpoint.
    /// </summary>
    value(10035400; "Copilot")
    {
        Caption = 'Copilot', Comment = 'is-IS=Copilot';
        Implementation = "Request Log Masker ori" = "Copilot Req Log Masker ori";
    }
}
