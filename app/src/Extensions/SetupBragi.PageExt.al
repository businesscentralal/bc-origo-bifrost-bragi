namespace Origo.Bifrost.Bragi;

using Origo.Bifrost;
using System.Apps;
using System.Environment.Configuration;

/// <summary>
/// Adds the Bifrost Language Models action to the Bifrost Foundation setup page,
/// and warns when HttpClient requests are blocked (the external chat providers
/// - OpenAI, Azure OpenAI, Custom LLM, Anthropic, xAI, Google/Gemini - need them).
/// </summary>
pageextension 10035403 "Setup Bragi ori" extends "Setup ori"
{
    actions
    {
        addafter(UserSystemPrompts)
        {
            action(BifrostLangModels)
            {
                ApplicationArea = All;
                Caption = 'Bifrost Language Models', Comment = 'is-IS=Bifröst mállíkön';
                ToolTip = 'Manage language models with skill content injected into the Bifrost Chat.', Comment = 'is-IS=Stjórna mállíkönum með hæfniefni sem er sett inn í Spjalla við Bifröst.';
                Image = Permission;
                RunObject = page "Bifrost LangModel List ori";
            }
        }
        addafter(UserSystemPrompts_Promoted)
        {
            actionref(BifrostLangModels_Promoted; BifrostLangModels)
            {
            }
        }
    }

    trigger OnOpenPage()
    begin
        ShowHttpClientNotification();
    end;

    local procedure ShowHttpClientNotification()
    var
        NavAppSetting: Record "NAV App Setting";
        HttpNotification: Notification;
        AppInfo: ModuleInfo;
        HttpClientDisabledMsg: Label 'HTTP client requests are not enabled for the Bifrost Bragi extension. The external chat providers (OpenAI, Azure OpenAI, Custom LLM, Anthropic, xAI, Google/Gemini) will not work until an administrator enables Allow HttpClient Requests in Extension Settings.', Comment = 'is-IS=HTTP-biðlarabeiðnir eru ekki virkar fyrir Bifröst Bragi viðbótina. Ytri spjallveitendur (OpenAI, Azure OpenAI, Custom LLM, Anthropic, xAI, Google/Gemini) virka ekki fyrr en kerfisstjóri virkjar Leyfa HttpClient-beiðnir í stillingum viðbótar.';
        EnableHttpClientLbl: Label 'Open Extension Settings', Comment = 'is-IS=Opna stillingar viðbótar';
    begin
        NavApp.GetCurrentModuleInfo(AppInfo);
        if NavAppSetting.Get(AppInfo.Id()) then
            if NavAppSetting."Allow HttpClient Requests" then
                exit;

        HttpNotification.Id := '8f1c6b2a-4e7d-4a91-9c3e-2d5f7a1b9e64';
        HttpNotification.Scope := NotificationScope::LocalScope;
        HttpNotification.Message := HttpClientDisabledMsg;
        HttpNotification.AddAction(EnableHttpClientLbl, Codeunit::"Chat Http Notif. Action ori", 'OpenExtensionSettings');
        HttpNotification.Send();
    end;
}
