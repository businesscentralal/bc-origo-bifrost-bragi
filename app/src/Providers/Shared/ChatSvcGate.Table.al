namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

/// <summary>
/// Permission gate table for the shared (service) LLM API key.
/// No records are stored — used solely as a WritePermission() check target
/// that controls who may view, set or clear a language model's shared API key.
/// </summary>
table 10035406 "Chat Svc Gate ori"
{
    Access = Internal;
    Caption = 'Chat Service Gate', Comment = 'is-IS=LLM þjónustuhlið';
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
