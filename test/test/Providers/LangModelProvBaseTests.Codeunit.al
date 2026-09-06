namespace Origo.Bifrost.Bragi.Test;
using Origo.Bifrost;
using Origo.Bifrost.Bragi;

using System.TestLibraries.Utilities;

/// <summary>
/// Tests for "LangModel Prov. Base ori": config resolution (IsConfigured, GetTimeoutMs,
/// GetMaxTokens), token-usage parsing, and multi-modal message building shared by every
/// chat provider.
/// </summary>
codeunit 96010 "LangModel Prov Base Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";

    [Test]
    procedure IsConfigured_WithKeyAndUrl_ReturnsTrue()
    var
        TempArg: Record "Bifrost Chat Argument ori" temporary;
        ProviderBase: Codeunit "LangModel Prov. Base ori";
    begin
        // [GIVEN] An argument with an API key and a Base URL
        TempArg.Init();
        TempArg."Base URL" := 'https://mock.test.local';
        TempArg.SetApiKey(AsSecret('test-key'));

        // [WHEN/THEN]
        Assert.IsTrue(ProviderBase.IsConfigured(TempArg, ''), 'Should be configured with key and URL');
    end;

    [Test]
    procedure IsConfigured_WithoutKey_ReturnsFalse()
    var
        TempArg: Record "Bifrost Chat Argument ori" temporary;
        ProviderBase: Codeunit "LangModel Prov. Base ori";
    begin
        // [GIVEN] An argument with a Base URL but no API key
        TempArg.Init();
        TempArg."Base URL" := 'https://mock.test.local';

        // [WHEN/THEN]
        Assert.IsFalse(ProviderBase.IsConfigured(TempArg, ''), 'Should not be configured without key');
    end;

    [Test]
    procedure IsConfigured_WithKeyNoUrl_UsesDefault()
    var
        TempArg: Record "Bifrost Chat Argument ori" temporary;
        ProviderBase: Codeunit "LangModel Prov. Base ori";
    begin
        // [GIVEN] An argument with a key but no Base URL
        TempArg.Init();
        TempArg.SetApiKey(AsSecret('some-key'));

        // [WHEN/THEN] Falls back to the provider default URL
        Assert.IsTrue(ProviderBase.IsConfigured(TempArg, 'https://default.com'),
            'Should be configured with key and default URL');
    end;

    [Test]
    procedure GetBaseUrl_ArgumentOverridesDefault()
    var
        TempArg: Record "Bifrost Chat Argument ori" temporary;
        ProviderBase: Codeunit "LangModel Prov. Base ori";
    begin
        // [GIVEN] An argument with an explicit Base URL
        TempArg.Init();
        TempArg."Base URL" := 'https://mock.test.local';

        // [WHEN/THEN] The argument value wins over the default
        Assert.AreEqual('https://mock.test.local', ProviderBase.GetBaseUrl(TempArg, 'https://default.com'),
            'Argument URL should override default');
    end;

    [Test]
    procedure GetBaseUrl_EmptyArgument_FallsBackToDefault()
    var
        TempArg: Record "Bifrost Chat Argument ori" temporary;
        ProviderBase: Codeunit "LangModel Prov. Base ori";
    begin
        TempArg.Init();
        Assert.AreEqual('https://default.com', ProviderBase.GetBaseUrl(TempArg, 'https://default.com'),
            'Should fall back to default');
    end;

    [Test]
    procedure GetModel_ArgumentOverridesDefault()
    var
        TempArg: Record "Bifrost Chat Argument ori" temporary;
        ProviderBase: Codeunit "LangModel Prov. Base ori";
    begin
        TempArg.Init();
        TempArg.Model := 'mock-model-1';
        Assert.AreEqual('mock-model-1', ProviderBase.GetModel(TempArg, 'default-model'),
            'Argument model should override default');
    end;

    [Test]
    procedure GetTimeoutMs_ArgumentValue_Used()
    var
        TempArg: Record "Bifrost Chat Argument ori" temporary;
        ProviderBase: Codeunit "LangModel Prov. Base ori";
    begin
        TempArg.Init();
        TempArg."Timeout Ms" := 60000;
        Assert.AreEqual(60000, ProviderBase.GetTimeoutMs(TempArg, 120000), 'Should use argument timeout');
    end;

    [Test]
    procedure GetTimeoutMs_Zero_UsesDefault()
    var
        TempArg: Record "Bifrost Chat Argument ori" temporary;
        ProviderBase: Codeunit "LangModel Prov. Base ori";
    begin
        TempArg.Init();
        Assert.AreEqual(120000, ProviderBase.GetTimeoutMs(TempArg, 120000), 'Should use default');
    end;

    [Test]
    procedure GetMaxTokens_ArgumentValue_Used()
    var
        TempArg: Record "Bifrost Chat Argument ori" temporary;
        ProviderBase: Codeunit "LangModel Prov. Base ori";
    begin
        TempArg.Init();
        TempArg."Max Tokens" := 2048;
        Assert.AreEqual(2048, ProviderBase.GetMaxTokens(TempArg, 4096), 'Should use argument value');
    end;

    [Test]
    procedure GetMaxTokens_Zero_UsesDefault()
    var
        TempArg: Record "Bifrost Chat Argument ori" temporary;
        ProviderBase: Codeunit "LangModel Prov. Base ori";
    begin
        TempArg.Init();
        Assert.AreEqual(4096, ProviderBase.GetMaxTokens(TempArg, 4096), 'Should use default');
    end;

    [Test]
    procedure ParseTokenUsage_StandardFormat()
    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        InTokens: Integer;
        OutTokens: Integer;
    begin
        // [GIVEN] Standard OpenAI usage format
        ProviderBase.ParseTokenUsage(
            '{"usage":{"prompt_tokens":150,"completion_tokens":42}}',
            InTokens, OutTokens);

        // [THEN]
        Assert.AreEqual(150, InTokens, 'Input tokens should be 150.');
        Assert.AreEqual(42, OutTokens, 'Output tokens should be 42.');
    end;

    [Test]
    procedure ParseTokenUsage_MissingUsage_ReturnsZero()
    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        InTokens: Integer;
        OutTokens: Integer;
    begin
        ProviderBase.ParseTokenUsage('{"model":"test"}', InTokens, OutTokens);
        Assert.AreEqual(0, InTokens, 'Missing usage should return 0.');
        Assert.AreEqual(0, OutTokens, 'Missing usage should return 0.');
    end;

    [Test]
    procedure ParseTokenUsage_InvalidJson_ReturnsZero()
    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        InTokens: Integer;
        OutTokens: Integer;
    begin
        ProviderBase.ParseTokenUsage('not json', InTokens, OutTokens);
        Assert.AreEqual(0, InTokens, 'Invalid JSON should return 0.');
        Assert.AreEqual(0, OutTokens, 'Invalid JSON should return 0.');
    end;

    [Test]
    procedure AttachFiles_AddsImageUrlBlock()
    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        PayloadObject: JsonObject;
        Messages: JsonArray;
        UserMsg: JsonObject;
        FilesArray: JsonArray;
        FileObj: JsonObject;
        LastMsg: JsonToken;
        ContentToken: JsonToken;
        ContentArray: JsonArray;
        FirstBlock: JsonToken;
    begin
        // [GIVEN] A user message and a PNG file in the payload
        UserMsg.Add('role', 'user');
        UserMsg.Add('content', 'Describe this image');
        Messages.Add(UserMsg);

        FileObj.Add('data', 'iVBORw0KGgo=');
        FileObj.Add('mimeType', 'image/png');
        FileObj.Add('fileName', 'test.png');
        FilesArray.Add(FileObj);
        PayloadObject.Add('files', FilesArray);

        // [WHEN] AttachFilesToMessages is called
        ProviderBase.AttachFilesToMessages(PayloadObject, Messages);

        // [THEN] The last message has a content array with text + image_url blocks
        Assert.AreEqual(1, Messages.Count(), 'Should still have 1 message.');
        Messages.Get(0, LastMsg);
        LastMsg.AsObject().Get('content', ContentToken);
        Assert.IsTrue(ContentToken.IsArray(), 'Content should be an array.');
        ContentArray := ContentToken.AsArray();
        Assert.AreEqual(2, ContentArray.Count(), 'Should have text + image blocks.');

        ContentArray.Get(0, FirstBlock);
        Assert.AreEqual('text', GetJsonText(FirstBlock.AsObject(), 'type'), 'First block should be text.');
        Assert.AreEqual('Describe this image', GetJsonText(FirstBlock.AsObject(), 'text'), 'Text should match prompt.');
    end;

    [Test]
    procedure AttachFiles_PdfUsesFileBlock()
    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        PayloadObject: JsonObject;
        Messages: JsonArray;
        UserMsg: JsonObject;
        FilesArray: JsonArray;
        FileObj: JsonObject;
        LastMsg: JsonToken;
        ContentToken: JsonToken;
        ContentArray: JsonArray;
        SecondBlock: JsonToken;
    begin
        // [GIVEN] A user message and a PDF file
        UserMsg.Add('role', 'user');
        UserMsg.Add('content', 'Extract data');
        Messages.Add(UserMsg);

        FileObj.Add('data', 'JVBERi0=');
        FileObj.Add('mimeType', 'application/pdf');
        FileObj.Add('fileName', 'invoice.pdf');
        FilesArray.Add(FileObj);
        PayloadObject.Add('files', FilesArray);

        // [WHEN]
        ProviderBase.AttachFilesToMessages(PayloadObject, Messages);

        // [THEN] The file block uses type=file (not image_url)
        Messages.Get(0, LastMsg);
        LastMsg.AsObject().Get('content', ContentToken);
        ContentArray := ContentToken.AsArray();
        ContentArray.Get(1, SecondBlock);
        Assert.AreEqual('file', GetJsonText(SecondBlock.AsObject(), 'type'), 'PDF should use file block type.');
    end;

    [Test]
    procedure AttachFiles_NoFiles_LeavesMessageUnchanged()
    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        PayloadObject: JsonObject;
        Messages: JsonArray;
        UserMsg: JsonObject;
        LastMsg: JsonToken;
        ContentToken: JsonToken;
    begin
        // [GIVEN] A user message with no files in payload
        UserMsg.Add('role', 'user');
        UserMsg.Add('content', 'Hello');
        Messages.Add(UserMsg);

        // [WHEN]
        ProviderBase.AttachFilesToMessages(PayloadObject, Messages);

        // [THEN] Message content remains a text string
        Messages.Get(0, LastMsg);
        LastMsg.AsObject().Get('content', ContentToken);
        Assert.IsTrue(ContentToken.IsValue(), 'Content should remain a text value when no files.');
        Assert.AreEqual('Hello', ContentToken.AsValue().AsText(), 'Text should be unchanged.');
    end;

    [Test]
    procedure AttachFiles_PreservesSystemMessage()
    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        PayloadObject: JsonObject;
        Messages: JsonArray;
        SystemMsg: JsonObject;
        UserMsg: JsonObject;
        FilesArray: JsonArray;
        FileObj: JsonObject;
        FirstMsg: JsonToken;
    begin
        // [GIVEN] A system message followed by a user message with a file
        SystemMsg.Add('role', 'system');
        SystemMsg.Add('content', 'You are a helper.');
        Messages.Add(SystemMsg);

        UserMsg.Add('role', 'user');
        UserMsg.Add('content', 'Process this');
        Messages.Add(UserMsg);

        FileObj.Add('data', 'abc=');
        FileObj.Add('mimeType', 'image/jpeg');
        FileObj.Add('fileName', 'photo.jpg');
        FilesArray.Add(FileObj);
        PayloadObject.Add('files', FilesArray);

        // [WHEN]
        ProviderBase.AttachFilesToMessages(PayloadObject, Messages);

        // [THEN] System message is preserved at index 0
        Assert.AreEqual(2, Messages.Count(), 'Should still have 2 messages.');
        Messages.Get(0, FirstMsg);
        Assert.AreEqual('system', GetJsonText(FirstMsg.AsObject(), 'role'), 'First message should be system.');
    end;

    local procedure GetJsonText(JObject: JsonObject; PropertyName: Text): Text
    var
        JToken: JsonToken;
    begin
        if JObject.Get(PropertyName, JToken) then
            if JToken.IsValue() then
                exit(JToken.AsValue().AsText());
    end;

    local procedure AsSecret(Value: Text) Secret: SecretText
    begin
        Secret := Value;
    end;
}
