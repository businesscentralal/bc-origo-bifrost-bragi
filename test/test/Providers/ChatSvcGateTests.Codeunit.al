namespace Origo.Bifrost.Bragi.Test;
using Origo.Bifrost.Bragi;

using System.TestLibraries.Utilities;

/// <summary>
/// Diagnostic tests for the shared (service) API key permission gate.
/// </summary>
codeunit 96013 "Chat Svc Gate Tests"
{
    Subtype = Test;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    [TestPermissions(TestPermissions::Disabled)]
    procedure ChatSvcGate_WritePermission_WithPermissionsDisabled()
    var
        ChatSvcGate: Record "Chat Svc Gate ori";
    begin
        // With TestPermissions=Disabled, WritePermission always returns true
        Assert.IsTrue(ChatSvcGate.WritePermission(), 'WritePermission should be true when permissions are disabled');
    end;

    [Test]
    [TestPermissions(TestPermissions::Disabled)]
    procedure ProviderBase_HasServiceKeyPermission_WithPermissionsDisabled()
    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
    begin
        Assert.IsTrue(ProviderBase.HasServiceKeyPermission(), 'HasServiceKeyPermission should be true when permissions are disabled');
    end;

    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure ChatSvcGate_WritePermission_WithRestrictivePermissions()
    var
        ChatSvcGate: Record "Chat Svc Gate ori";
    begin
        // With Restrictive, this tests whether the test runner's effective permissions include the gate.
        // If this fails, the BIFROST ChatSvc permission set is not in the test runner's effective permissions.
        Assert.IsTrue(ChatSvcGate.WritePermission(),
            'WritePermission should be true. Assign BIFROST ChatSvc (Chat Service Gate) permission set to the test user.');
    end;

    [Test]
    [TestPermissions(TestPermissions::Disabled)]
    procedure ChatSvcGate_Table_IsAccessible()
    var
        ChatSvcGate: Record "Chat Svc Gate ori";
    begin
        // Verifies the table is accessible and can be queried
        ChatSvcGate.SetRange("Primary Key", 'DIAG');
        Assert.IsFalse(ChatSvcGate.FindFirst(), 'Diagnostic key should not exist');
    end;
}
