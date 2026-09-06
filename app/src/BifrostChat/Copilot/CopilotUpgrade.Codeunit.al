namespace Origo.Bifrost.Bragi;
using Origo.Bifrost;

using System.Upgrade;

/// <summary>
/// Ensures the Copilot capability is registered after upgrade, and that every language model
/// has its API key secrets registered with the Bifrost Foundation secret store.
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

    trigger OnUpgradePerCompany()
    var
        Install: Codeunit "Copilot Install ori";
    begin
        Install.RegisterSecrets();
    end;
}
