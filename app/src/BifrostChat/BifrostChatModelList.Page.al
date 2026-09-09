namespace Origo.Bifrost.LanguageModels;
using Microsoft.Utilities;

using Origo.Bifrost;

/// <summary>
/// Generic lookup page for selecting an Bifrost chat AI model.
/// Provider extensions populate the temporary Name/Value Buffer via
/// "Bifrost Chat Mgt ori".GetAvailableModels and pass it in with Set().
/// </summary>
page 10035342 "Bifrost Chat Model List ori"
{
    Caption = 'Available Models', Comment = 'is-IS=Tiltæk líkön';
    PageType = List;
    ApplicationArea = All;
    UsageCategory = None;
    SourceTable = "Name/Value Buffer";
    SourceTableTemporary = true;
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Models)
            {
                field(Name; Rec.Name)
                {
                    ApplicationArea = All;
                    Caption = 'Model', Comment = 'is-IS=Líkan';
                    ToolTip = 'Specifies the AI model identifier available from the active Chat via Bifrost provider.', Comment = 'is-IS=Tilgreinir auðkenni gervigreindarlíkans sem er tiltækt frá virkum Bifröst Spjallveitanda.';
                }
            }
        }
    }

    /// <summary>
    /// Copies the provided temporary Name/Value Buffer into the page's source so it
    /// can be displayed and used as a lookup.
    /// </summary>
    /// <param name="NameValueBuffer">Source buffer (typically populated by a provider).</param>
    procedure Set(var NameValueBuffer: Record "Name/Value Buffer")
    begin
        Rec.Copy(NameValueBuffer, true);
    end;
}
