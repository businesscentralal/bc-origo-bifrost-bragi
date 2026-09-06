namespace Origo.Bifrost.Bragi;
using Origo.Bifrost;

/// <summary>
/// Handles the notification action to open Extension Management for enabling HTTP client requests.
/// </summary>
codeunit 10035408 "Chat Http Notif. Action ori"
{
    Access = Internal;

    /// <summary>
    /// Opens the Extension Management page where the administrator can enable Allow HttpClient Requests.
    /// </summary>
    internal procedure OpenExtensionSettings(Notification: Notification)
    begin
        Hyperlink(GetUrl(ClientType::Web, CompanyName, ObjectType::Page, 2500));
    end;
}
