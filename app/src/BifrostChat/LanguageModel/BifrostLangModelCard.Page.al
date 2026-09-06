namespace Origo.Bifrost.Bragi;
using Microsoft.Utilities;

/// <summary>
/// Card page for editing an Bifrost Language Model, including its skill content (markdown).
/// Provides an Import Defaults action to fetch skill content from the standard URL.
/// </summary>

using Origo.Bifrost;
using System.Reflection;
using System.Utilities;

page 10035343 "Bifrost LangModel Card ori"
{
    Caption = 'Bifrost Language Model', Comment = 'is-IS=Bifröst mállíkan';
    ContextSensitiveHelpPage = 'bifrost-lang-model-card';
    PageType = Card;
    SourceTable = "Bifrost Language Model ori";
    ApplicationArea = All;
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            group(General)
            {
                Caption = 'General', Comment = 'is-IS=Almennt';

                field("Code"; Rec."Code")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the unique code for this language model.', Comment = 'is-IS=Tilgreinir einkvæman kóða þessa mállíkans.';
                }
                field(Description; Rec.Description)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies a description of what this language model does.', Comment = 'is-IS=Tilgreinir lýsingu á því hvað þetta mállíkan gerir.';
                }
                field(Default; Rec.Default)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies whether this is the default language model assigned to users without an explicit language model setup.', Comment = 'is-IS=Tilgreinir hvort þetta sé sjálfgefið mállíkan sem er úthlutað notendum sem hafa ekki sérstaka mállíkansstillingu.';
                }
                field("Chat Provider"; Rec."Chat Provider")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the chat provider for this language model. None inherits the user-level provider.', Comment = 'is-IS=Tilgreinir spjallveitandann fyrir þetta mállíkan. Enginn erfir notandastigs veitandann.';

                    trigger OnValidate()
                    begin
                        CurrPage.Update(false);
                    end;
                }
            }
            group(ProviderConfig)
            {
                Caption = 'Provider Configuration', Comment = 'is-IS=Stillingar veitanda';

                field("Base URL"; Rec."Base URL")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the API endpoint URL for this provider.', Comment = 'is-IS=Tilgreinir API endapunktsslóð fyrir þennan veitanda.';
                    Enabled = HasExternalEndpoint;
                    ShowMandatory = BaseUrlRequired;
                }

                field("Timeout Seconds"; Rec."Timeout Seconds")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the request timeout in seconds. 0 uses the provider default.', Comment = 'is-IS=Tilgreinir tímamörk beiðni í sekúndum. 0 notar sjálfgefin gildi veitanda.';
                    Enabled = HasExternalEndpoint;
                }
                field("Max Tokens"; Rec."Max Tokens")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the maximum number of tokens in the response. 0 uses the provider default.', Comment = 'is-IS=Tilgreinir hámarksfjölda tókena í svari. 0 notar sjálfgefin gildi veitanda.';
                    Enabled = HasExternalEndpoint;
                }
                field("Chat Path"; Rec."Chat Path")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the chat endpoint path. Leave empty for /v1/chat/completions.', Comment = 'is-IS=Tilgreinir spjallslóð. Skildu eftir autt fyrir /v1/chat/completions.';
                    Enabled = ChatPathVisible;
                    ShowMandatory = ChatPathVisible;
                }
                field("Models Path"; Rec."Models Path")
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the models endpoint path. Leave empty for /v1/models.', Comment = 'is-IS=Tilgreinir líkanaslóð. Skilðu eftir autt fyrir /v1/models.';
                    Enabled = ModelsPathVisible;
                    ShowMandatory = ModelsPathVisible;
                }
                field(Model; Rec.Model)
                {
                    ApplicationArea = All;
                    ToolTip = 'Specifies the AI model to use. Leave empty for the provider default.', Comment = 'is-IS=Tilgreinir gervigreindarlíkanið sem á að nota. Skildu eftir autt fyrir sjálfgefið líkan veitanda.';
                    Enabled = HasExternalEndpoint;
                    ShowMandatory = ModelRequired;

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        TempNameValueBuffer: Record "Name/Value Buffer" temporary;
                        TempArgument: Record "Bifrost Chat Argument ori" temporary;
                        TestCtx: Codeunit "Bifrost LangModel Test Ctx ori";
                        Provider: Interface "Bifrost LangModel Provider ori";
                        NoLookupMsg: Label 'This provider does not support model lookup. Type the model name manually.', Comment = 'is-IS=Þessi veitandi styður ekki uppflettingu á líkönum. Sláðu inn heiti líkansins handvirkt.';
                    begin
                        Provider := Rec."Chat Provider";
                        if not GetProviderBool(Provider, TempArgument, TempArgument."Procedure Type"::SupportsModelSelection) then begin
                            Message(NoLookupMsg);
                            exit(false);
                        end;
                        TestCtx.SetLanguageModel(Rec.Code);
                        BuildPageArgument(TempArgument);
                        ExecuteProvider(Provider, TempArgument, TempArgument."Procedure Type"::GetAvailableModels);
                        TempArgument.GetModels(TempNameValueBuffer);
                        if not TempArgument."Result Boolean" then begin
                            TestCtx.ClearLanguageModel();
                            exit(false);
                        end;
                        TestCtx.ClearLanguageModel();
                        TempNameValueBuffer.Name := Rec.Model;
                        if Page.RunModal(Page::"Name/Value Lookup", TempNameValueBuffer) = Action::LookupOK then begin
                            Text := TempNameValueBuffer.Name;
                            exit(true);
                        end;
                        exit(false);
                    end;
                }
            }
            group(Authentication)
            {
                Caption = 'Authentication', Comment = 'is-IS=Auðkenning';
                Visible = RequiresApiKeyVisible;

                field(PersonalApiKey; PersonalApiKeyValue)
                {
                    ApplicationArea = All;
                    Caption = 'Personal API Key', Comment = 'is-IS=Persónulegur API-lykill';
                    ToolTip = 'Enter your personal API key. Stored per-user and takes priority over the service key. Clear the field to remove the stored key.', Comment = 'is-IS=Sláðu inn persónulegan API-lykil. Geymdur á hvern notanda og hefur forgang yfir þjónustulykil. Hreinsaðu reitinn til að fjarlægja geymdan lykil.';
                    ExtendedDatatype = Masked;

                    trigger OnValidate()
                    var
                        UserKeyTok: Label 'Bifrost_Chat_Usr_', Locked = true;
                        StorageKey: Text;
                    begin
                        CurrPage.SaveRecord();
                        StorageKey := UserKeyTok + Format(Rec.SystemId, 0, 4) + '_' + Format(UserSecurityId(), 0, 4);
                        if (PersonalApiKeyValue = '') or (PersonalApiKeyValue = MaskedKeyTok) then begin
                            if HasPersonalKey and (PersonalApiKeyValue = '') then
                                if IsolatedStorage.Contains(StorageKey, DataScope::Company) then
                                    IsolatedStorage.Delete(StorageKey, DataScope::Company);
                        end else
                            IsolatedStorage.Set(StorageKey, PersonalApiKeyValue, DataScope::Company);
                        Clear(PersonalApiKeyValue);
                        UpdateAuthFlags();
                    end;
                }
                field(HasPersonalKeyField; HasPersonalKey)
                {
                    ApplicationArea = All;
                    Caption = 'Personal Key Stored', Comment = 'is-IS=Persónulegur lykill geymdur';
                    ToolTip = 'Indicates whether you have a personal API key stored.', Comment = 'is-IS=Gefur til kynna hvort þú sért með persónulegan API-lykil geymdan.';
                    Editable = false;
                }
                field(ServiceApiKey; ServiceApiKeyValue)
                {
                    ApplicationArea = All;
                    Caption = 'Service API Key', Comment = 'is-IS=Þjónustu API-lykill';
                    ToolTip = 'Enter a shared service key used by all users without a personal key. Clear the field to remove the stored key.', Comment = 'is-IS=Sláðu inn sameiginlegan þjónustulykil sem allir notendur nota sem hafa ekki persónulegan lykil. Hreinsaðu reitinn til að fjarlægja geymdan lykil.';
                    ExtendedDatatype = Masked;
                    Enabled = HasServiceKeyPerm;

                    trigger OnValidate()
                    var
                        ServiceKeyTok: Label 'Bifrost_Chat_Svc_', Locked = true;
                        StorageKey: Text;
                    begin
                        CurrPage.SaveRecord();
                        StorageKey := ServiceKeyTok + Format(Rec.SystemId, 0, 4);
                        if (ServiceApiKeyValue = '') or (ServiceApiKeyValue = MaskedKeyTok) then begin
                            if HasServiceKey and (ServiceApiKeyValue = '') then
                                if IsolatedStorage.Contains(StorageKey, DataScope::Company) then
                                    IsolatedStorage.Delete(StorageKey, DataScope::Company);
                        end else
                            IsolatedStorage.Set(StorageKey, ServiceApiKeyValue, DataScope::Company);
                        Clear(ServiceApiKeyValue);
                        UpdateAuthFlags();
                    end;
                }
                field(HasServiceKeyField; HasServiceKey)
                {
                    ApplicationArea = All;
                    Caption = 'Service Key Stored', Comment = 'is-IS=Þjónustulykill geymdur';
                    ToolTip = 'Indicates whether a shared service API key is stored.', Comment = 'is-IS=Gefur til kynna hvort sameiginlegur þjónustulykill sé geymdur.';
                    Editable = false;
                    Enabled = HasServiceKeyPerm;
                }
            }
            group(SkillContent)
            {
                Caption = 'Skill', Comment = 'is-IS=Hæfni';
                InstructionalText = 'The markdown skill instructions injected into the chat when this language model is active.', Comment = 'is-IS=Hæfnileiðbeiningar á markdown-sniði sem eru settar inn í spjallið þegar þetta mállíkan er virkt.';
            }
            usercontrol(SkillEditor; "Text Editor ori")
            {
                ApplicationArea = All;

                trigger ControlReady()
                begin
                    CurrPage.SkillEditor.SetPlaceholder(SkillPlaceholderTxt);
                    CurrPage.SkillEditor.SetReadOnly(not CurrPage.Editable());
                    CurrPage.SkillEditor.SetContent(Rec.GetSkill());
                end;

                trigger ContentChanged(Content: Text)
                begin
                    if not CurrPage.Editable() then
                        exit;

                    Rec.SetSkill(Content);
                    Rec.Modify(true);
                end;
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ImportDefaults)
            {
                ApplicationArea = All;
                Caption = 'Import Defaults', Comment = 'is-IS=Flytja inn sjálfgildi';
                ToolTip = 'Downloads the default skill content from the provider and populates this language model.', Comment = 'is-IS=Sækir sjálfgefið hæfniefni frá veitanda og fyllir þetta mállíkan.';
                Image = Import;
                Enabled = HasDefaultSkillUrl;

                trigger OnAction()
                var
                    ImportSuccessMsg: Label 'Default skill content imported successfully.', Comment = 'is-IS=Sjálfgefið hæfniefni flutt inn.';
                begin
                    if not Rec.ImportDefaultSkillResult() then
                        exit;
                    SkillTextValue := Rec.GetSkill();
                    CurrPage.SkillEditor.SetContent(SkillTextValue);
                    Message(ImportSuccessMsg);
                end;
            }
            action(TestConnection)
            {
                ApplicationArea = All;
                Caption = 'Test Connection', Comment = 'is-IS=Prófa tengingu';
                ToolTip = 'Verifies that the selected provider is available and operational.', Comment = 'is-IS=Staðfestir að valinn veitandi sé tiltækur og starfhæfur.';
                Image = ValidateEmailLoggingSetup;

                trigger OnAction()
                var
                    TempArgument: Record "Bifrost Chat Argument ori" temporary;
                    TestCtx: Codeunit "Bifrost LangModel Test Ctx ori";
                    Provider: Interface "Bifrost LangModel Provider ori";
                    SuccessMsg: Label 'Connection test passed.', Comment = 'is-IS=Tengipróf tókst.';
                begin
                    Provider := Rec."Chat Provider";
                    TestCtx.SetLanguageModel(Rec.Code);
                    BuildPageArgument(TempArgument);
                    ExecuteProvider(Provider, TempArgument, TempArgument."Procedure Type"::TestConnection);
                    if TempArgument."Result Boolean" then
                        Message(SuccessMsg)
                    else
                        Error(TempArgument.GetErrorMessage());
                    TestCtx.ClearLanguageModel();
                end;
            }
            action(GetApiKey)
            {
                ApplicationArea = All;
                Caption = 'Get API Key', Comment = 'is-IS=Sækja API-lykil';
                ToolTip = 'Opens the provider documentation page where you can obtain an API key.', Comment = 'is-IS=Opnar skjalsíðu veitanda þar sem hægt er að sækja API-lykil.';
                Image = LinkWeb;
                Enabled = HasApiKeyDocsUrl;

                trigger OnAction()
                var
                    TempArgument: Record "Bifrost Chat Argument ori" temporary;
                    Provider: Interface "Bifrost LangModel Provider ori";
                begin
                    Provider := Rec."Chat Provider";
                    Hyperlink(GetProviderText(Provider, TempArgument, TempArgument."Procedure Type"::GetApiKeyDocsUrl));
                end;
            }
            action(TryIt)
            {
                ApplicationArea = All;
                Caption = 'Try It', Comment = 'is-IS=Prófa';
                ToolTip = 'Opens a chat session using this language model so you can test it.', Comment = 'is-IS=Opnar spjall með þessu mállíkani svo þú getir prófað það.';
                Image = Action;

                trigger OnAction()
                var
                    TestCtx: Codeunit "Bifrost LangModel Test Ctx ori";
                begin
                    CurrPage.SaveRecord();
                    Commit();
                    TestCtx.SetLanguageModel(Rec.Code);
                    Page.RunModal(Page::"Chat Focus ori");
                    TestCtx.ClearLanguageModel();
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process', Comment = 'is-IS=Vinnsla';

                actionref(ImportDefaults_Promoted; ImportDefaults) { }
                actionref(TestConnection_Promoted; TestConnection) { }
                actionref(TryIt_Promoted; TryIt) { }
                actionref(GetApiKey_Promoted; GetApiKey) { }
            }
        }
    }

    var
        SkillTextValue: Text;
        SkillPlaceholderTxt: Label 'Enter skill instructions in markdown...', Comment = 'is-IS=Sláðu inn hæfnileiðbeiningar á markdown-sniði...';
        MaskedKeyTok: Label '••••••••••••', Locked = true;
        HasExternalEndpoint: Boolean;
        ChatPathVisible: Boolean;
        ModelsPathVisible: Boolean;
        BaseUrlRequired: Boolean;
        ModelRequired: Boolean;
        HasApiKeyDocsUrl: Boolean;
        HasDefaultSkillUrl: Boolean;
        RequiresApiKeyVisible: Boolean;
        HasPersonalKey: Boolean;
        HasServiceKey: Boolean;
        HasServiceKeyPerm: Boolean;
        PersonalApiKeyValue: Text[2048];
        ServiceApiKeyValue: Text[2048];

    trigger OnAfterGetCurrRecord()
    begin
        SkillTextValue := Rec.GetSkill();
        CurrPage.SkillEditor.SetReadOnly(not CurrPage.Editable());
        CurrPage.SkillEditor.SetContent(SkillTextValue);
        UpdateProviderFlags();
        UpdateAuthFlags();
    end;

    local procedure UpdateProviderFlags()
    var
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        Provider: Interface "Bifrost LangModel Provider ori";
    begin
        Provider := Rec."Chat Provider";
        HasExternalEndpoint := GetProviderBool(Provider, TempArgument, TempArgument."Procedure Type"::HasExternalEndpoint);
        ChatPathVisible := GetProviderBool(Provider, TempArgument, TempArgument."Procedure Type"::RequiresChatPath);
        ModelsPathVisible := GetProviderBool(Provider, TempArgument, TempArgument."Procedure Type"::RequiresModelsPath);
        BaseUrlRequired := HasExternalEndpoint and (GetProviderText(Provider, TempArgument, TempArgument."Procedure Type"::GetDefaultBaseUrl) = '');
        ModelRequired := HasExternalEndpoint and (GetProviderText(Provider, TempArgument, TempArgument."Procedure Type"::GetDefaultModel) = '');
        HasApiKeyDocsUrl := GetProviderText(Provider, TempArgument, TempArgument."Procedure Type"::GetApiKeyDocsUrl) <> '';
        HasDefaultSkillUrl := (GetProviderText(Provider, TempArgument, TempArgument."Procedure Type"::GetDefaultSkillUrl) <> '') or (GetProviderText(Provider, TempArgument, TempArgument."Procedure Type"::GetDefaultSkillText) <> '');
        RequiresApiKeyVisible := GetProviderBool(Provider, TempArgument, TempArgument."Procedure Type"::RequiresApiKey);
    end;

    local procedure UpdateAuthFlags()
    var
        TempArgument: Record "Bifrost Chat Argument ori" temporary;
        Provider: Interface "Bifrost LangModel Provider ori";
        UserKeyTok: Label 'Bifrost_Chat_Usr_', Locked = true;
        ServiceKeyTok: Label 'Bifrost_Chat_Svc_', Locked = true;
    begin
        Provider := Rec."Chat Provider";
        if not GetProviderBool(Provider, TempArgument, TempArgument."Procedure Type"::RequiresApiKey) then begin
            HasPersonalKey := false;
            HasServiceKey := false;
            HasServiceKeyPerm := false;
            exit;
        end;
        HasServiceKeyPerm := GetProviderBool(Provider, TempArgument, TempArgument."Procedure Type"::HasServiceKeyPermission);
        HasServiceKey := IsolatedStorage.Contains(ServiceKeyTok + Format(Rec.SystemId, 0, 4), DataScope::Company);
        HasPersonalKey := IsolatedStorage.Contains(UserKeyTok + Format(Rec.SystemId, 0, 4) + '_' + Format(UserSecurityId(), 0, 4), DataScope::Company);
        if HasPersonalKey then
            PersonalApiKeyValue := MaskedKeyTok
        else
            Clear(PersonalApiKeyValue);
        if HasServiceKey then
            ServiceApiKeyValue := MaskedKeyTok
        else
            Clear(ServiceApiKeyValue);
    end;

    [NonDebuggable]
    local procedure BuildPageArgument(var TempArgument: Record "Bifrost Chat Argument ori" temporary)
    var
        UserKeyTok: Label 'Bifrost_Chat_Usr_', Locked = true;
        ServiceKeyTok: Label 'Bifrost_Chat_Svc_', Locked = true;
        ApiKeyValue: Text;
    begin
        TempArgument.Init();
        TempArgument."Language Model SystemId" := Rec.SystemId;
        TempArgument."Base URL" := Rec."Base URL";
        TempArgument.Model := Rec.Model;
        TempArgument."Timeout Ms" := Rec."Timeout Seconds" * 1000;
        TempArgument."Max Tokens" := Rec."Max Tokens";
        TempArgument."Chat Path" := Rec."Chat Path";
        TempArgument."Models Path" := Rec."Models Path";
        if IsolatedStorage.Get(UserKeyTok + Format(Rec.SystemId, 0, 4) + '_' + Format(UserSecurityId(), 0, 4), DataScope::Company, ApiKeyValue) then
            if ApiKeyValue <> '' then begin
                TempArgument.SetApiKey(ApiKeyValue);
                exit;
            end;
        if IsolatedStorage.Get(ServiceKeyTok + Format(Rec.SystemId, 0, 4), DataScope::Company, ApiKeyValue) then
            TempArgument.SetApiKey(ApiKeyValue);
    end;

    local procedure ExecuteProvider(var Provider: Interface "Bifrost LangModel Provider ori"; var TempArgument: Record "Bifrost Chat Argument ori" temporary; ProcType: Enum "Bifrost Chat Proc. Type ori")
    begin
        TempArgument."Procedure Type" := ProcType;
        TempArgument."Result Boolean" := false;
        TempArgument."Result Integer" := 0;
        TempArgument.SetResultText('');
        TempArgument.SetErrorMessage('');
        Provider.Execute(TempArgument);
    end;

    local procedure GetProviderBool(var Provider: Interface "Bifrost LangModel Provider ori"; var TempArgument: Record "Bifrost Chat Argument ori" temporary; ProcType: Enum "Bifrost Chat Proc. Type ori"): Boolean
    begin
        ExecuteProvider(Provider, TempArgument, ProcType);
        exit(TempArgument."Result Boolean");
    end;

    local procedure GetProviderText(var Provider: Interface "Bifrost LangModel Provider ori"; var TempArgument: Record "Bifrost Chat Argument ori" temporary; ProcType: Enum "Bifrost Chat Proc. Type ori"): Text
    begin
        ExecuteProvider(Provider, TempArgument, ProcType);
        exit(TempArgument.GetResultText());
    end;

}
