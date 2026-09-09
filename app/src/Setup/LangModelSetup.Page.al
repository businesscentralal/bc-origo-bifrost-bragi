namespace Origo.Bifrost.LanguageModels;

using Origo.Bifrost;

/// <summary>
/// Setup page of Bifrost Language Models, opened from the Apps group on the Bifrost Setup page.
/// It shows the state of the language models, of the MCP tool server and of the API keys
/// Bifrost Language Models keeps in the Bifrost Foundation secret store.
/// Setup notifications - including the one about blocked HttpClient requests - are raised by
/// Bifrost Foundation on the Bifrost Setup page, never here.
/// </summary>
page 10035421 "LangModel Setup ori"
{
    Caption = 'Bifrost Language Models Setup', Comment = 'is-IS=Uppsetning Bifröst mállíkana';
    ContextSensitiveHelpPage = 'bragi-setup';
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = None;
    InsertAllowed = false;
    DeleteAllowed = false;
    Editable = false;

    layout
    {
        area(Content)
        {
            group(LanguageModels)
            {
                Caption = 'Language Models', Comment = 'is-IS=Mállíkön';
                InstructionalText = 'A language model connects Chat via Bifrost to a provider - Copilot, OpenAI, Azure OpenAI, a custom LLM, Anthropic, xAI or Google Gemini - and carries the skill content injected into every chat.', Comment = 'is-IS=Mállíkan tengir Spjalla með Bifröst við veitanda - Copilot, OpenAI, Azure OpenAI, sérsniðið LLM, Anthropic, xAI eða Google Gemini - og ber hæfniefnið sem er sett inn í hvert spjall.';

                field(LanguageModelCount; LanguageModelCount)
                {
                    Caption = 'Language Models', Comment = 'is-IS=Mállíkön';
                    ToolTip = 'Specifies how many language models are set up in this company.', Comment = 'is-IS=Tilgreinir hversu mörg mállíkön eru sett upp í þessu fyrirtæki.';
                    DrillDown = true;

                    trigger OnDrillDown()
                    begin
                        Page.Run(Page::"Bifrost LangModel List ori");
                    end;
                }
                field(DefaultLanguageModel; DefaultLanguageModelCode)
                {
                    Caption = 'Default Language Model', Comment = 'is-IS=Sjálfgefið mállíkan';
                    ToolTip = 'Specifies the language model used by everyone who has no language model assigned in user setup.', Comment = 'is-IS=Tilgreinir mállíkanið sem allir nota sem hafa ekki mállíkan í notandauppsetningu.';
                }
            }
            group(ToolServer)
            {
                Caption = 'MCP Tool Server', Comment = 'is-IS=MCP verkfæraþjónn';
                InstructionalText = 'Chat via Bifrost exposes the Bifrost message types to the language model as Model Context Protocol tools, so the model can read and write Business Central data on your behalf.', Comment = 'is-IS=Spjalla með Bifröst birtir mállíkaninu skilaboðategundir Bifröst sem Model Context Protocol verkfæri, svo líkanið geti lesið og skrifað gögn í Business Central fyrir þína hönd.';

                field(ToolCount; ToolCount)
                {
                    Caption = 'Available Tools', Comment = 'is-IS=Tiltæk verkfæri';
                    ToolTip = 'Specifies how many Model Context Protocol tools the chat can call in this company.', Comment = 'is-IS=Tilgreinir hversu mörg Model Context Protocol verkfæri spjallið getur kallað á í þessu fyrirtæki.';
                }
            }
            group(Secrets)
            {
                Caption = 'API Keys', Comment = 'is-IS=API-lyklar';
                InstructionalText = 'Bifrost Language Models keeps every provider API key in the Bifrost secret store. Each language model has a shared key for the whole company and a personal key per user.', Comment = 'is-IS=Bifröst mállíkön geyma alla API-lykla veitenda í leyndarmálageymslu Bifröst. Hvert mállíkan hefur sameiginlegan lykil fyrir allt fyrirtækið og persónulegan lykil fyrir hvern notanda.';

                field(ModelsWithoutKey; ModelsWithoutKeyCount)
                {
                    Caption = 'Language Models Without a Key', Comment = 'is-IS=Mállíkön án lykils';
                    ToolTip = 'Specifies how many language models need an API key but have neither a shared key nor a personal key stored for you.', Comment = 'is-IS=Tilgreinir hversu mörg mállíkön þurfa API-lykil en hafa hvorki sameiginlegan lykil né persónulegan lykil geymdan fyrir þig.';
                    StyleExpr = MissingKeyStyleExpr;
                    DrillDown = true;

                    trigger OnDrillDown()
                    begin
                        Page.Run(Page::"Bifrost LangModel List ori");
                    end;
                }
                field(KeyHint; KeyHintText)
                {
                    Caption = 'Note', Comment = 'is-IS=Athugasemd';
                    ToolTip = 'Specifies what to do about the API keys that are still missing.', Comment = 'is-IS=Tilgreinir hvað eigi að gera við API-lyklana sem vantar enn.';
                    MultiLine = true;
                    Visible = KeyHintVisible;
                    StyleExpr = MissingKeyStyleExpr;
                    ShowCaption = false;
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(LanguageModelList)
            {
                ApplicationArea = All;
                Caption = 'Language Models', Comment = 'is-IS=Mállíkön';
                ToolTip = 'Manage the language models with the skill content injected into Chat via Bifrost.', Comment = 'is-IS=Stjórna mállíkönum með hæfniefni sem er sett inn í Spjalla með Bifröst.';
                Image = Permission;
                RunObject = page "Bifrost LangModel List ori";
            }
            action(AppSecrets)
            {
                ApplicationArea = All;
                Caption = 'API Keys', Comment = 'is-IS=API-lyklar';
                ToolTip = 'Show the API keys Bifrost Language Models has registered in the Bifrost secret store and whether a value has been entered.', Comment = 'is-IS=Sýna API-lyklana sem Bifröst mállíkön hafa skráð í leyndarmálageymslu Bifröst og hvort gildi hafi verið skráð.';
                Image = EncryptionKeys;

                trigger OnAction()
                var
                    LangModelSecrets: Codeunit "LangModel Secrets ori";
                    AppSecretsPage: Page "App Secrets ori";
                begin
                    LangModelSecrets.RegisterAll();
                    AppSecretsPage.SetAppFilter(LangModelSecrets.GetAppId());
                    AppSecretsPage.Run();
                end;
            }
            action(SetupWizard)
            {
                ApplicationArea = All;
                Caption = 'Setup Wizard', Comment = 'is-IS=Uppsetningarleiðsögn';
                ToolTip = 'Opens the Bifrost setup wizard, which enables HTTP client requests for all Bifrost apps and walks through the credentials of every app.', Comment = 'is-IS=Opnar uppsetningarleiðsögn Bifröst, sem virkjar HTTP biðlarabeiðnir fyrir öll Bifröst forrit og fer yfir auðkenni hvers forrits.';
                Image = Setup;
                RunObject = page "Setup Wizard ori";
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process', Comment = 'is-IS=Vinnsla';

                actionref(LanguageModelList_Promoted; LanguageModelList) { }
                actionref(AppSecrets_Promoted; AppSecrets) { }
                actionref(SetupWizard_Promoted; SetupWizard) { }
            }
        }
    }

    var
        DefaultLanguageModelCode: Text[50];
        KeyHintText: Text;
        MissingKeyStyleExpr: Text;
        LanguageModelCount: Integer;
        ToolCount: Integer;
        ModelsWithoutKeyCount: Integer;
        KeyHintVisible: Boolean;
        UnfavorableStyleTok: Label 'Unfavorable', Locked = true;
        FavorableStyleTok: Label 'Favorable', Locked = true;
        KeyMissingHintTxt: Label 'API keys cannot be moved from another extension. Open a language model and use Set Personal API Key or Set Shared API Key to enter each key once.', Comment = 'is-IS=Ekki er hægt að flytja API-lykla frá annarri viðbót. Opnaðu mállíkan og notaðu Skrá persónulegan API-lykil eða Skrá sameiginlegan API-lykil til að slá hvern lykil inn einu sinni.';
        NoDefaultLanguageModelTxt: Label '(none)', Comment = 'is-IS=(ekkert)';

    trigger OnOpenPage()
    var
        LangModelSecrets: Codeunit "LangModel Secrets ori";
    begin
        LangModelSecrets.RegisterAll();
        RefreshStatus();
    end;

    local procedure RefreshStatus()
    var
        LangModel: Record "Bifrost Language Model ori";
        LangModelSecrets: Codeunit "LangModel Secrets ori";
        MCPServer: Codeunit "MCP Tool Server ori";
    begin
        LangModel.ReadIsolation := IsolationLevel::ReadUncommitted;
        LangModel.SetLoadFields(Code, Default);
        LanguageModelCount := LangModel.Count();

        DefaultLanguageModelCode := '';
        LangModel.SetRange(Default, true);
        if LangModel.FindFirst() then
            DefaultLanguageModelCode := CopyStr(LangModel.Code, 1, MaxStrLen(DefaultLanguageModelCode));
        LangModel.SetRange(Default);

        ToolCount := MCPServer.GetToolCount();
        ModelsWithoutKeyCount := LangModelSecrets.CountModelsWithoutKey();

        KeyHintVisible := ModelsWithoutKeyCount > 0;
        if KeyHintVisible then begin
            KeyHintText := KeyMissingHintTxt;
            MissingKeyStyleExpr := UnfavorableStyleTok;
        end else begin
            KeyHintText := '';
            MissingKeyStyleExpr := FavorableStyleTok;
        end;

        if DefaultLanguageModelCode = '' then
            DefaultLanguageModelCode := CopyStr(NoDefaultLanguageModelTxt, 1, MaxStrLen(DefaultLanguageModelCode));
    end;
}
