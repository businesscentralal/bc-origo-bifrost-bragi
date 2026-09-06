namespace Origo.Bifrost.Bragi;
using Microsoft.Utilities;

/// <summary>
/// Defines Bifrost Language Models with associated skill content (markdown).
/// Each role stores a skill blob that is injected into the chat control
/// as the system-level instruction when selected in user setup.
/// </summary>

using Origo.Bifrost;
using System.Utilities;

table 10035335 "Bifrost Language Model ori"
{
    Access = Public;
    Caption = 'Bifrost Language Model', Comment = 'is-IS=Bifröst mállíkan';
    DataClassification = CustomerContent;
    LookupPageId = "Bifrost LangModel List ori";
    DrillDownPageId = "Bifrost LangModel List ori";

    fields
    {
        field(1; "Code"; Code[20])
        {
            Caption = 'Code', Comment = 'is-IS=Kóði';
            DataClassification = CustomerContent;
            NotBlank = true;
        }
        field(2; Description; Text[100])
        {
            Caption = 'Description', Comment = 'is-IS=Lýsing';
            DataClassification = CustomerContent;
        }
        field(10; Skill; Blob)
        {
            Caption = 'Skill', Comment = 'is-IS=Hæfni';
            DataClassification = CustomerContent;
        }
        field(11; Default; Boolean)
        {
            Caption = 'Default', Comment = 'is-IS=Sjálfgefið';
            DataClassification = CustomerContent;

            trigger OnValidate()
            var
                OtherRole: Record "Bifrost Language Model ori";
                OnlyOneDefaultErr: Label 'Language model %1 is already the default. Only one language model can be the default.', Comment = '%1 = role code, is-IS=Mállíkan %1 er þegar sjálfgefið. Aðeins eitt mállíkan getur verið sjálfgefið.';
            begin
                if not Default then
                    exit;
                OtherRole.SetRange(Default, true);
                OtherRole.SetFilter(Code, '<>%1', Code);
                if OtherRole.FindFirst() then
                    Error(OnlyOneDefaultErr, OtherRole.Code);
            end;
        }
        field(12; "Chat Provider"; Enum "Bifrost LangModel Prov. ori")
        {
            Caption = 'Chat Provider', Comment = 'is-IS=Spjallveitandi';
            DataClassification = CustomerContent;

            trigger OnValidate()
            var
                TempArg: Record "Bifrost Chat Argument ori" temporary;
                Provider: Interface "Bifrost LangModel Provider ori";
                ProcType: Enum "Bifrost Chat Proc. Type ori";
            begin
                Provider := "Chat Provider";
                TempArg.Init();
                TempArg."Procedure Type" := ProcType::HasExternalEndpoint;
                Provider.Execute(TempArg);
                if TempArg."Result Boolean" then begin
                    if "Base URL" = '' then begin
                        TempArg."Procedure Type" := ProcType::GetDefaultBaseUrl;
                        Provider.Execute(TempArg);
                        "Base URL" := CopyStr(TempArg.GetResultText(), 1, MaxStrLen("Base URL"));
                    end;
                    if Model = '' then begin
                        TempArg."Procedure Type" := ProcType::GetDefaultModel;
                        Provider.Execute(TempArg);
                        Model := CopyStr(TempArg.GetResultText(), 1, MaxStrLen(Model));
                    end;
                    if "Timeout Seconds" = 0 then begin
                        TempArg."Procedure Type" := ProcType::GetDefaultTimeoutSeconds;
                        Provider.Execute(TempArg);
                        "Timeout Seconds" := TempArg."Result Integer";
                    end;
                    if "Max Tokens" = 0 then begin
                        TempArg."Procedure Type" := ProcType::GetDefaultMaxTokens;
                        Provider.Execute(TempArg);
                        "Max Tokens" := TempArg."Result Integer";
                    end;
                end else begin
                    "Base URL" := '';
                    Model := '';
                    "Timeout Seconds" := 0;
                    "Max Tokens" := 0;
                end;
            end;
        }
        field(20; "Base URL"; Text[250])
        {
            Caption = 'Base URL', Comment = 'is-IS=Grunnslóð';
            DataClassification = CustomerContent;
        }
        field(21; Model; Text[100])
        {
            Caption = 'Model', Comment = 'is-IS=Líkan';
            DataClassification = CustomerContent;
        }
        field(22; "Timeout Seconds"; Integer)
        {
            Caption = 'Timeout Seconds', Comment = 'is-IS=Tímamörk (sekúndur)';
            DataClassification = CustomerContent;
            MinValue = 0;
            MaxValue = 600;
        }
        field(23; "Max Tokens"; Integer)
        {
            Caption = 'Max Tokens', Comment = 'is-IS=Hámarksfjöldi tókena';
            DataClassification = CustomerContent;
            MinValue = 0;
            MaxValue = 128000;
        }
        field(24; "Chat Path"; Text[250])
        {
            Caption = 'Chat Path', Comment = 'is-IS=Spjallslóð';
            DataClassification = CustomerContent;
        }
        field(25; "Models Path"; Text[250])
        {
            Caption = 'Models Path', Comment = 'is-IS=Líkanaslóð';
            DataClassification = CustomerContent;
        }
    }

    keys
    {
        key(PK; "Code")
        {
            Clustered = true;
        }
    }

    trigger OnInsert()
    var
        BragiSecrets: Codeunit "Bragi Secrets ori";
    begin
        BragiSecrets.Register(Code);
    end;

    trigger OnRename()
    var
        BragiSecrets: Codeunit "Bragi Secrets ori";
    begin
        BragiSecrets.MoveSecrets(xRec.Code, Code);
    end;

    trigger OnDelete()
    var
        BragiSecrets: Codeunit "Bragi Secrets ori";
    begin
        BragiSecrets.ClearSecrets(Code);
    end;

    /// <summary>
    /// Gets the skill markdown text from the blob field.
    /// </summary>
    /// <returns>The stored skill text, or empty string if no content.</returns>
    procedure GetSkill() SkillText: Text
    var
        InStr: InStream;
    begin
        CalcFields(Skill);
        if not Skill.HasValue() then
            exit('');
        Skill.CreateInStream(InStr, TextEncoding::UTF8);
        InStr.Read(SkillText)
    end;

    /// <summary>
    /// Sets the skill markdown text into the blob field.
    /// </summary>
    /// <param name="SkillText">The markdown skill content to store.</param>
    procedure SetSkill(SkillText: Text)
    var
        OutStr: OutStream;
    begin
        Clear(Skill);
        Skill.CreateOutStream(OutStr, TextEncoding::UTF8);
        OutStr.Write(SkillText);
    end;

    /// <summary>
    /// Imports default skill content — from the provider's URL if available,
    /// or from the provider's embedded skill text.
    /// Returns true if content was imported, false if the user cancelled.
    /// </summary>
    procedure ImportDefaultSkillResult(): Boolean
    var
        TempArg: Record "Bifrost Chat Argument ori" temporary;
        ConfirmMgt: Codeunit "Confirm Management";
        Provider: Interface "Bifrost LangModel Provider ori";
        ProcType: Enum "Bifrost Chat Proc. Type ori";
        SkillUrl: Text;
        SkillText: Text;
        OverwriteQst: Label 'Skill content already exists for language model %1. Do you want to overwrite it?', Comment = '%1 = Code, is-IS=H\u00e6fniefni er \u00feegar til fyrir m\u00e1ll\u00edkan %1. Viltu skrifa yfir \u00fea\u00f0?';
        NoDefaultSkillErr: Label 'The selected provider does not have default skill content.', Comment = 'is-IS=Valinn veitandi hefur ekki sj\u00e1lfgefi\u00f0 h\u00e6fniefni.';
    begin
        Provider := "Chat Provider";
        TempArg.Init();
        TempArg."Procedure Type" := ProcType::GetDefaultSkillUrl;
        Provider.Execute(TempArg);
        SkillUrl := TempArg.GetResultText();
        TempArg."Procedure Type" := ProcType::GetDefaultSkillText;
        Provider.Execute(TempArg);
        SkillText := TempArg.GetResultText();

        if (SkillUrl = '') and (SkillText = '') then
            Error(NoDefaultSkillErr);

        CalcFields(Skill);
        if Skill.HasValue() then
            if not ConfirmMgt.GetResponseOrDefault(StrSubstNo(OverwriteQst, Code), false) then
                exit(false);

        if SkillUrl <> '' then
            SkillText := DownloadSkill(SkillUrl);

        SetSkill(SkillText);
        Modify(true);
        exit(true);
    end;

    local procedure DownloadSkill(SkillUrl: Text) SkillText: Text
    var
        HttpClient: HttpClient;
        HttpResponse: HttpResponseMessage;
        ImportFailedErr: Label 'Failed to download skill content from %1.', Comment = '%1 = URL, is-IS=Ekki tókst að sækja hæfniefni frá %1.';
    begin
        if not HttpClient.Get(SkillUrl, HttpResponse) then
            Error(ImportFailedErr, SkillUrl);
        if not HttpResponse.IsSuccessStatusCode() then
            Error(ImportFailedErr, SkillUrl);
        HttpResponse.Content.ReadAs(SkillText);
    end;
}
