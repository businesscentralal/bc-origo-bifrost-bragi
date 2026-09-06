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
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [GIVEN] a restricted user that only holds the Chat Service permission set
        LibraryLowerPermissions.SetO365Basic();
        LibraryLowerPermissions.AddPermissionSet('BIFROST ChatSvc ori');

        // [THEN] the gate table grants write permission
        Assert.IsTrue(ChatSvcGate.WritePermission(), 'BIFROST ChatSvc ori must grant write permission on the Chat Service gate');
    end;

    [Test]
    [TestPermissions(TestPermissions::Restrictive)]
    procedure ChatSvcGate_WritePermission_WithoutPermissionSet()
    var
        ChatSvcGate: Record "Chat Svc Gate ori";
        LibraryLowerPermissions: Codeunit "Library - Lower Permissions";
    begin
        // [GIVEN] a restricted user without the Chat Service permission set
        LibraryLowerPermissions.SetO365Basic();

        // [THEN] the gate denies write permission
        Assert.IsFalse(ChatSvcGate.WritePermission(), 'a user without BIFROST ChatSvc ori must not pass the Chat Service gate');
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
