namespace Origo.Bifrost.Bragi;
using Origo.Bifrost;

/// <summary>
/// Grants Bifrost Chat capability.
/// Users with this permission set may use the Bifrost Chat FactBox/Focus page
/// and invoke LLM.Prompt.Complete via the API.
/// Not bundled into Bifrost Read or Bifrost Full — administrators must assign explicitly.
/// </summary>
permissionset 10035398 "BIFROST Chat ori"
{
    Assignable = true;
    Caption = 'Chat Gate', MaxLength = 30, Comment = 'is-IS=Spjallhlið';

    Permissions =
        tabledata "Chat Gate ori" = RIMD;
}
