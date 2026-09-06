namespace Origo.Bifrost.Bragi.Test;

using Origo.Bifrost;
using Origo.Bifrost.Bragi;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests for the Bragi setup surface: the new "Bragi Setup ori" page opens and reports the
/// language models, the MCP tools and the missing API keys, and the Bifrost Foundation setup
/// page carries the single Apps action Bragi is allowed to contribute.
/// </summary>
codeunit 96014 "Bragi Setup Page Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        Any: Codeunit Any;
        IsInitialized: Boolean;

    local procedure Initialize()
    begin
        if IsInitialized then
            exit;

        IsInitialized := true;
    end;

    [Test]
    [HandlerFunctions('NotificationHandler')]
    procedure BragiSetupPage_Opens()
    var
        BragiSetupPage: TestPage "Bragi Setup ori";
    begin
        // [SCENARIO] The Bragi setup page opens and shows its status fields.
        Initialize();

        // [WHEN] The page is opened
        BragiSetupPage.OpenView();

        // [THEN] The status fields are readable
        Assert.IsTrue(BragiSetupPage.LanguageModelCount.AsInteger() >= 0, 'The language model count must be readable.');
        Assert.IsTrue(BragiSetupPage.ToolCount.AsInteger() >= 0, 'The MCP tool count must be readable.');
        Assert.IsTrue(BragiSetupPage.ModelsWithoutKey.AsInteger() >= 0, 'The missing key count must be readable.');

        BragiSetupPage.Close();
    end;

    [Test]
    [HandlerFunctions('NotificationHandler')]
    procedure BragiSetupPage_CountsTheLanguageModels()
    var
        LangModel: Record "Bifrost Language Model ori";
        BragiSetupPage: TestPage "Bragi Setup ori";
        CountBefore: Integer;
    begin
        // [SCENARIO] The language model count on the setup page follows the table.
        Initialize();

        // [GIVEN] The count shown before a language model is added
        BragiSetupPage.OpenView();
        CountBefore := BragiSetupPage.LanguageModelCount.AsInteger();
        BragiSetupPage.Close();

        // [WHEN] A language model is created and the page is reopened
        LangModel.Init();
        LangModel.Code := CopyStr('X-PAGE-' + Format(Any.IntegerInRange(100000, 999999)), 1, MaxStrLen(LangModel.Code));
        LangModel.Insert(true);

        BragiSetupPage.OpenView();

        // [THEN] The count went up by one
        Assert.AreEqual(CountBefore + 1, BragiSetupPage.LanguageModelCount.AsInteger(), 'The setup page must count the new language model.');

        BragiSetupPage.Close();
    end;

    [Test]
    [HandlerFunctions('NotificationHandler')]
    procedure SetupOri_ExposesTheSingleBragiAppsAction()
    var
        BifrostSetupPage: TestPage "Setup ori";
    begin
        // [SCENARIO] Bragi contributes exactly one action to the Apps group of Bifrost Setup.
        // The removed action "BifrostLangModels" and its actionref are enforced by the
        // compiler: referring to them here would not compile.
        Initialize();

        // [WHEN] The Bifrost Foundation setup page is opened
        BifrostSetupPage.OpenView();

        // [THEN] The one Bragi action is there and enabled
        Assert.IsTrue(BifrostSetupPage.BragiSetup.Enabled(), 'The Bragi Setup action must be enabled on Bifrost Setup.');
        Assert.IsTrue(BifrostSetupPage.BragiSetup.Visible(), 'The Bragi Setup action must be visible on Bifrost Setup.');

        BifrostSetupPage.Close();
    end;

    [SendNotificationHandler]
    procedure NotificationHandler(var TheNotification: Notification): Boolean
    begin
        exit(true);
    end;
}
