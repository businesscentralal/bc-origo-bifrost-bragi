namespace Origo.Bifrost.Bragi;
using Origo.Bifrost;

using System.Upgrade;

/// <summary>
/// Ensures the Copilot capability is registered after upgrade.
/// </summary>
codeunit 10035391 "Copilot Upgrade ori"
{
    Access = Internal;
    Subtype = Upgrade;

    trigger OnUpgradePerDatabase()
    var
        Install: Codeunit "Copilot Install ori";
    begin
        Install.RegisterCapability();
    end;
}
