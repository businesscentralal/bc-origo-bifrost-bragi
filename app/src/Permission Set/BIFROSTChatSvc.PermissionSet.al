namespace Origo.Bifrost.Bragi;
using Origo.Bifrost;

/// <summary>
/// Grants access to the shared LLM API key on a Bifrost Language Model.
/// Users with this permission set can view, set or clear the shared (service) key
/// that other users without a personal key fall back to.
/// Not bundled into Bifrost Read, Bifrost Full or Bifrost Chat — administrators
/// must assign it explicitly.
/// </summary>
permissionset 10035407 "BIFROST ChatSvc ori"
{
    Assignable = true;
    Caption = 'Chat Service Gate', MaxLength = 30, Comment = 'is-IS=LLM þjónustuhlið';

    Permissions =
        tabledata "Chat Svc Gate ori" = RIMD;
}
