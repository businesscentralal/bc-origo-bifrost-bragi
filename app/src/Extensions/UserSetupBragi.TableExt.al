namespace Origo.Bifrost.Bragi;

using Origo.Bifrost;

/// <summary>
/// Adds the per-user language model assignment to the Bifrost Foundation user setup table.
/// The assigned language model supplies the skill content injected into the Bifrost Chat.
/// </summary>
tableextension 10035401 "User Setup Bragi ori" extends "User Setup ori"
{
    fields
    {
        field(10035401; "Bifrost Language Model Code"; Code[20])
        {
            Caption = 'Bifrost Language Model Code', Comment = 'is-IS=Kóði Bifröst mállíkans';
            DataClassification = CustomerContent;
            TableRelation = "Bifrost Language Model ori";
        }
    }
}
