namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

using System.AI;

/// <summary>
/// Install codeunit of Bifrost Language Models.
/// Per database it registers the Copilot capability with Microsoft's Copilot framework; the same
/// registration runs again from "Copilot Upgrade ori".
/// Per company it takes over the data of the published Origo Cloud Events Chat app, which the chat
/// providers (OpenAI, Azure OpenAI, Custom LLM, Anthropic, xAI, Google/Gemini) replace, and registers
/// the API key secrets of every existing language model with the Foundation secret store.
/// It never creates a language model: InitDefaultLanguageModel is called only on demand, from the
/// "Init Copilot Defaults" action on the Bifrost Language Model List page, so that installing the
/// app writes no setup data on its own.
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
    procedure RegisterSecrets()
    var
        LangModelSecrets: Codeunit "LangModel Secrets ori";
    begin
        LangModelSecrets.RegisterAll();
    end;

    procedure RegisterCapability()
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

    procedure InitDefaultLanguageModel()
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
