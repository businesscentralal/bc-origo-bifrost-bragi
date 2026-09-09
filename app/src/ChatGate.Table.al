namespace Origo.Bifrost.Bragi;
using Origo.Bifrost;

/// <summary>
/// Permission gate table for Bifrost Chat.
/// No records are stored — used solely as a WritePermission() check target
/// that controls access to the Bifrost Chat UI and LLM.Prompt.Complete message type.
/// </summary>
table 10035336 "Chat Gate ori"
{
    Access = Internal;
    Caption = 'Bifrost Chat Gate', Comment = 'is-IS=Spjallhlið Bifröst';
    DataClassification = SystemMetadata;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            Caption = 'Primary Key', Comment = 'is-IS=Aðallykill';
            DataClassification = SystemMetadata;
        }
    }
    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }
}
