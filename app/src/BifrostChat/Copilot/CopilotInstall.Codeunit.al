namespace Origo.Bifrost.Bragi;
using Origo.Bifrost;

using System.AI;

/// <summary>
/// Registers the Copilot capability on install and creates a default Copilot language model.
/// The capability is registered again from the upgrade codeunit; the default language model is
/// created only on demand, from the "Init Copilot Defaults" action on the Bifrost Language Model
/// List page, so that installing Bragi never writes setup data on its own.
/// Also takes over per-company data from the published Origo Cloud Events Chat app, which the
/// chat providers (OpenAI, Azure OpenAI, Custom LLM, Anthropic, xAI, Google/Gemini) replace.
/// </summary>
codeunit 10035390 "Copilot Install ori"
{
    Access = Internal;
    Subtype = Install;

    trigger OnInstallAppPerDatabase()
    begin
        RegisterCapability();
    end;

    trigger OnInstallAppPerCompany()
    var
        ChatProvidersInstall: Codeunit "Chat Providers Install ori";
    begin
        ChatProvidersInstall.TakeOverChatProviderData();
        RegisterSecrets();
    end;

    /// <summary>
    /// Registers the API key secrets of every existing language model with the Bifrost Foundation
    /// secret store, so the administrator sees on Bifrost App Secrets which keys still need a value.
    /// Idempotent - called from install and from upgrade.
    /// </summary>
    internal procedure RegisterSecrets()
    var
        BragiSecrets: Codeunit "Bragi Secrets ori";
    begin
        BragiSecrets.RegisterAll();
    end;

    internal procedure RegisterCapability()
    var
        CopilotCapability: Codeunit "Copilot Capability";
        LearnMoreUrlTok: Label 'https://www.origo.is/', Locked = true;
    begin
        if not CopilotCapability.IsCapabilityRegistered(Enum::"Copilot Capability"::"Bifrost Chat ori") then
            CopilotCapability.RegisterCapability(
                Enum::"Copilot Capability"::"Bifrost Chat ori",
                Enum::"Copilot Availability"::"Generally Available",
                Enum::"Copilot Billing Type"::"Microsoft Billed",
                LearnMoreUrlTok)
        else
            CopilotCapability.ModifyCapability(
                Enum::"Copilot Capability"::"Bifrost Chat ori",
                Enum::"Copilot Availability"::"Generally Available",
                Enum::"Copilot Billing Type"::"Microsoft Billed",
                LearnMoreUrlTok);
    end;

    internal procedure InitDefaultLanguageModel()
    var
        LangModel: Record "Bifrost Language Model ori";
        DefaultSkill: Codeunit "Copilot Default Skill ori";
        CopilotCodeTok: Label 'COPILOT', Locked = true;
        CopilotDescTok: Label 'Bifrost Copilot', Comment = 'is-IS=Bifröst Copilot';
    begin
        if LangModel.Get(CopilotCodeTok) then begin
            // Update skill on existing role
            LangModel.SetSkill(DefaultSkill.GetSkillText());
#pragma warning disable AA0214
            LangModel.Modify(true);
#pragma warning restore AA0214
            exit;
        end;

        LangModel.Init();
        LangModel.Code := CopilotCodeTok;
        LangModel.Description := CopilotDescTok;
        LangModel."Chat Provider" := Enum::"Bifrost LangModel Prov. ori"::Copilot;
        LangModel.SetSkill(DefaultSkill.GetSkillText());

        LangModel.SetRange(Default, true);
        if LangModel.IsEmpty() then
            LangModel.Default := true;
        LangModel.SetRange(Default);

        LangModel.Insert(true);
    end;
}
