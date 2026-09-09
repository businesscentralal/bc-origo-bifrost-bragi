namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

/// <summary>
/// Masker for Copilot request log entries. Logging only occurs in debug mode,
/// so bodies are passed through unredacted.
/// </summary>
codeunit 10035394 "Copilot Req Log Masker ori" implements "Request Log Masker ori"
{
    Access = Internal;

    procedure MaskRequestBody(Body: Text; DebugMode: Boolean): Text
    begin
        exit(Body);
    end;

    procedure MaskResponseBody(Body: Text; DebugMode: Boolean): Text
    begin
        exit(Body);
    end;

    procedure MaskErrorText(ErrorText: Text; DebugMode: Boolean): Text
    begin
        exit(ErrorText);
    end;

    procedure GetBaseUrl(FullUrl: Text): Text
    begin
        exit('Azure OpenAI (Managed)');
    end;
}
