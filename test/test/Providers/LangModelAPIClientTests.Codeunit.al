namespace Origo.Bifrost.LanguageModels.Test;
using Origo.Bifrost.LanguageModels;

using System.TestLibraries.Utilities;

/// <summary>
/// Tests for "LangModel API Client ori".ExtractText — parsing the assistant text out
/// of an OpenAI-compatible chat completions response, including edge cases.
/// </summary>
codeunit 96011 "LangModel API Client Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure ExtractText_StandardResponse()
    var
        ApiClient: Codeunit "LangModel API Client ori";
        Response: JsonObject;
    begin
        // [GIVEN] A standard OpenAI response
        Response.ReadFrom('{"choices":[{"message":{"content":"Hello world"},"finish_reason":"stop"}]}');

        // [WHEN/THEN]
        Assert.AreEqual('Hello world', ApiClient.ExtractText(Response), 'Should extract content from choices.');
    end;

    [Test]
    procedure ExtractText_EmptyChoices_ReturnsEmpty()
    var
        ApiClient: Codeunit "LangModel API Client ori";
        Response: JsonObject;
    begin
        Response.ReadFrom('{"choices":[]}');
        Assert.AreEqual('', ApiClient.ExtractText(Response), 'Empty choices should return empty.');
    end;

    [Test]
    procedure ExtractText_NoChoices_ReturnsEmpty()
    var
        ApiClient: Codeunit "LangModel API Client ori";
        Response: JsonObject;
    begin
        Response.ReadFrom('{"id":"test"}');
        Assert.AreEqual('', ApiClient.ExtractText(Response), 'Missing choices should return empty.');
    end;

    [Test]
    procedure ExtractText_ContentIsNull_ReturnsEmpty()
    var
        ApiClient: Codeunit "LangModel API Client ori";
        Response: JsonObject;
    begin
        // [GIVEN] Response where content is null
        Response.ReadFrom('{"choices":[{"message":{"content":null},"finish_reason":"stop"}]}');

        // [WHEN/THEN]
        Assert.AreEqual('', ApiClient.ExtractText(Response), 'Null content should return empty.');
    end;

    [Test]
    procedure ExtractText_ContentArray_ReturnsEmpty()
    var
        ApiClient: Codeunit "LangModel API Client ori";
        Response: JsonObject;
    begin
        // [GIVEN] Response where content is an array (multi-modal response) — ExtractText only
        // handles string content on the OpenAI-compatible path.
        Response.ReadFrom('{"choices":[{"message":{"content":[{"type":"text","text":"hello"}]},"finish_reason":"stop"}]}');

        // [WHEN/THEN]
        Assert.AreEqual('', ApiClient.ExtractText(Response), 'Array content should return empty (not a value).');
    end;
}
