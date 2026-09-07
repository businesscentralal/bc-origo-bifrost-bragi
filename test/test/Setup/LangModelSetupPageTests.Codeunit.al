namespace Origo.Bifrost.LanguageModels.Test;

using Origo.Bifrost;
using Origo.Bifrost.LanguageModels;
using System.TestLibraries.Utilities;

/// <summary>
/// Tests for the Bifrost Language Models setup surface: the new "LangModel Setup ori" page opens and reports the
/// language models, the MCP tools and the missing API keys, and the Bifrost Foundation setup
/// page carries the single Apps action Bifrost Language Models is allowed to contribute.
/// </summary>
codeunit 96014 "LangModel Setup Page Tests"
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
    procedure LangModelSetupPage_Opens()
    var
        LangModelSetupPage: TestPage "LangModel Setup ori";
    begin
        // [SCENARIO] The Bifrost Language Models setup page opens and shows its status fields.
        Initialize();

        // [WHEN] The page is opened
        LangModelSetupPage.OpenView();

        // [THEN] The status fields are readable
        Assert.IsTrue(LangModelSetupPage.LanguageModelCount.AsInteger() >= 0, 'The language model count must be readable.');
        Assert.IsTrue(LangModelSetupPage.ToolCount.AsInteger() >= 0, 'The MCP tool count must be readable.');
        Assert.IsTrue(LangModelSetupPage.ModelsWithoutKey.AsInteger() >= 0, 'The missing key count must be readable.');

        LangModelSetupPage.Close();
    end;

    [Test]
    [HandlerFunctions('NotificationHandler')]
    procedure LangModelSetupPage_CountsTheLanguageModels()
    var
        LangModel: Record "Bifrost Language Model ori";
        LangModelSetupPage: TestPage "LangModel Setup ori";
        CountBefore: Integer;
    begin
        // [SCENARIO] The language model count on the setup page follows the table.
        Initialize();

        // [GIVEN] The count shown before a language model is added
        LangModelSetupPage.OpenView();
        CountBefore := LangModelSetupPage.LanguageModelCount.AsInteger();
        LangModelSetupPage.Close();

        // [WHEN] A language model is created and the page is reopened
        LangModel.Init();
        LangModel.Code := CopyStr('X-PAGE-' + Format(Any.IntegerInRange(100000, 999999)), 1, MaxStrLen(LangModel.Code));
        LangModel.Insert(true);

        LangModelSetupPage.OpenView();

        // [THEN] The count went up by one
        Assert.AreEqual(CountBefore + 1, LangModelSetupPage.LanguageModelCount.AsInteger(), 'The setup page must count the new language model.');

        LangModelSetupPage.Close();
    end;

    [Test]
    procedure SetupOri_ExposesTheSingleLangModelAppsAction()
    var
        BifrostSetupPage: TestPage "Setup ori";
    begin
        // [SCENARIO] Bifrost Language Models contributes exactly one action to the Apps group of Bifrost Setup.
        // The removed action "BifrostLangModels" and its actionref are enforced by the
        // compiler: referring to them here would not compile.
        // No NotificationHandler here on purpose: the HttpClient notification moved to
        // "LangModel Setup ori", so opening "Setup ori" sends no notification and a declared
        // handler would never run.
        Initialize();

        // [WHEN] The Bifrost Foundation setup page is opened
        BifrostSetupPage.OpenView();

        // [THEN] The one Bifrost Language Models action is there and enabled
        Assert.IsTrue(BifrostSetupPage.LangModelSetup.Enabled(), 'The Bifrost Language Models Setup action must be enabled on Bifrost Setup.');
        Assert.IsTrue(BifrostSetupPage.LangModelSetup.Visible(), 'The Bifrost Language Models Setup action must be visible on Bifrost Setup.');

        BifrostSetupPage.Close();
    end;

    [SendNotificationHandler]
    procedure NotificationHandler(var TheNotification: Notification): Boolean
    begin
        exit(true);
    end;
}
