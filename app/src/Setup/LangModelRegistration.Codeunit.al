namespace Origo.Bifrost.LanguageModels;

using Origo.Bifrost;

/// <summary>
/// Makes Bifrost Language Models known to Bifrost Foundation's application registry.
/// Setup notifications are raised on the Bifrost Setup page only - this app never shows one of
/// its own; it registers its module id and the object id of its setup page here, and Bifrost
/// Foundation aggregates the outstanding setup work from the registry.
/// </summary>
codeunit 10035423 "LangModel Registration ori"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"App Registry ori", OnRegisterApps, '', false, false)]
    local procedure RegisterApp(var Apps: Record "Registered App ori" temporary)
    var
        AppRegistry: Codeunit "App Registry ori";
        AppInfo: ModuleInfo;
    begin
        NavApp.GetCurrentModuleInfo(AppInfo);
        AppRegistry.AddApp(Apps, AppInfo.Id(), CopyStr(AppInfo.Name(), 1, 250), Page::"LangModel Setup ori");
    end;
}
