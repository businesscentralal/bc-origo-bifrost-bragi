namespace Origo.Bifrost.LanguageModels.Test;
using Origo.Bifrost.LanguageModels;

using System.TestLibraries.Utilities;

/// <summary>
/// Tests for "LLM Req Log Masker ori" — the masker Bifrost Foundation applies to every
/// request log entry of type LLM. It decides what an administrator reading the request log
/// gets to see of an LLM call: the full prompt and reply in debug mode, a redaction marker
/// otherwise, and never more of the endpoint than scheme plus host.
/// </summary>
codeunit 96015 "LLM Req Log Masker Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        RedactedTok: Label '***REDACTED***', Locked = true;

    [Test]
    procedure MaskRequestBody_DebugMode_ReturnsBodyUnchanged()
    var
        Masker: Codeunit "LLM Req Log Masker ori";
        Body: Text;
    begin
        // [GIVEN] A chat completions request body
        Body := '{"model":"gpt-4o","messages":[{"role":"user","content":"hello"}]}';

        // [WHEN] The masker runs in debug mode
        // [THEN] The body is stored verbatim — debug mode is the deliberate opt-in that lets an
        // administrator read the prompt that was sent
        Assert.AreEqual(Body, Masker.MaskRequestBody(Body, true), 'Debug mode must keep the request body.');
    end;

    [Test]
    procedure MaskRequestBody_NormalMode_IsRedacted()
    var
        Masker: Codeunit "LLM Req Log Masker ori";
        Body: Text;
    begin
        // [GIVEN] A request body carrying the user's prompt
        Body := '{"model":"gpt-4o","messages":[{"role":"user","content":"invoice 1234 for ACME"}]}';

        // [WHEN/THEN] Outside debug mode nothing of the body reaches the log
        Assert.AreEqual(RedactedTok, Masker.MaskRequestBody(Body, false), 'Normal mode must redact the request body.');
    end;

    [Test]
    procedure MaskResponseBody_DebugMode_ReturnsBodyUnchanged()
    var
        Masker: Codeunit "LLM Req Log Masker ori";
        Body: Text;
    begin
        Body := '{"choices":[{"message":{"content":"Hello world"}}]}';
        Assert.AreEqual(Body, Masker.MaskResponseBody(Body, true), 'Debug mode must keep the response body.');
    end;

    [Test]
    procedure MaskResponseBody_NormalMode_IsRedacted()
    var
        Masker: Codeunit "LLM Req Log Masker ori";
        Body: Text;
    begin
        Body := '{"choices":[{"message":{"content":"Hello world"}}]}';
        Assert.AreEqual(RedactedTok, Masker.MaskResponseBody(Body, false), 'Normal mode must redact the response body.');
    end;

    [Test]
    procedure MaskResponseBody_EmptyBody_StaysEmptyInDebugMode()
    var
        Masker: Codeunit "LLM Req Log Masker ori";
    begin
        // [GIVEN] A call that produced no response body (transport failure)
        // [WHEN/THEN] Debug mode must not invent content
        Assert.AreEqual('', Masker.MaskResponseBody('', true), 'An empty body must stay empty in debug mode.');
    end;

    [Test]
    procedure MaskErrorText_IsNeverRedacted()
    var
        Masker: Codeunit "LLM Req Log Masker ori";
        ErrorText: Text;
    begin
        // [GIVEN] The error detail of a failed provider call
        ErrorText := 'LLM API returned status 429. Rate limit reached.';

        // [WHEN/THEN] The error text is kept in both modes — it is what an administrator
        // troubleshoots with, and the provider never returns the API key in it
        Assert.AreEqual(ErrorText, Masker.MaskErrorText(ErrorText, false), 'Error text must survive normal mode.');
        Assert.AreEqual(ErrorText, Masker.MaskErrorText(ErrorText, true), 'Error text must survive debug mode.');
    end;

    [Test]
    procedure GetBaseUrl_StripsPathAndQuery()
    var
        Masker: Codeunit "LLM Req Log Masker ori";
    begin
        // [GIVEN] A full chat completions endpoint with a path and a query string
        // [WHEN/THEN] Only scheme and host are logged — anything a provider puts in the path
        // or the query stays out of the request log
        Assert.AreEqual('https://api.openai.com',
            Masker.GetBaseUrl('https://api.openai.com/v1/chat/completions'), 'Path must be stripped.');
        Assert.AreEqual('https://generativelanguage.googleapis.com',
            Masker.GetBaseUrl('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?alt=json'),
            'Path and query must be stripped.');
    end;

    [Test]
    procedure GetBaseUrl_HostOnly_ReturnsHost()
    var
        Masker: Codeunit "LLM Req Log Masker ori";
    begin
        Assert.AreEqual('https://api.anthropic.com',
            Masker.GetBaseUrl('https://api.anthropic.com'), 'A host without a path is already the base URL.');
    end;

    [Test]
    procedure GetBaseUrl_NoScheme_ReturnsInput()
    var
        Masker: Codeunit "LLM Req Log Masker ori";
    begin
        // [GIVEN] A value that is not a URL at all
        // [WHEN/THEN] It is returned unchanged rather than truncated to nothing
        Assert.AreEqual('not-a-url', Masker.GetBaseUrl('not-a-url'), 'A value without a scheme is returned as is.');
    end;

    [Test]
    procedure GetBaseUrl_Empty_ReturnsEmpty()
    var
        Masker: Codeunit "LLM Req Log Masker ori";
    begin
        Assert.AreEqual('', Masker.GetBaseUrl(''), 'An empty URL stays empty.');
    end;
}
