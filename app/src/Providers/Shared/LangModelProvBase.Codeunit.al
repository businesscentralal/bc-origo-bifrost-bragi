namespace Origo.Bifrost.Bragi;
using Origo.Bifrost;

/// <summary>
/// Shared helper procedures for Bifrost Chat language-model providers: config resolution,
/// service-key permission checks, token-usage parsing and multi-modal message building.
/// </summary>
codeunit 10035410 "LangModel Prov. Base ori"
{
    Access = Internal;

    var
        HttpClientBlockedMsg: Label 'HttpClient calls are blocked in this environment. An administrator must allow AL HttpClient requests.', Comment = 'is-IS=HttpClient köll eru lokuð í þessu umhverfi. Stjórnandi þarf að leyfa AL HttpClient beiðnir.';
        ServiceGateDeniedErr: Label 'No language model is configured with a chat provider. Set up a Bifrost Language Model with a Chat Provider.', Comment = 'is-IS=Ekkert mállíkan er stillt með spjallveitanda. Settu upp Bifröst mállíkan með spjallveitanda.';

    /// <summary>
    /// Returns whether the current user may view, set or clear the shared (service) API key.
    /// </summary>
    internal procedure HasServiceKeyPermission(): Boolean
    var
        ChatSvcGate: Record "Chat Svc Gate ori";
    begin
        exit(ChatSvcGate.WritePermission());
    end;

    /// <summary>
    /// Returns the argument's Base URL, or the provider default when blank.
    /// </summary>
    internal procedure GetBaseUrl(var Argument: Record "Bifrost Chat Argument ori" temporary; DefaultUrl: Text): Text
    begin
        if Argument."Base URL" <> '' then
            exit(Argument."Base URL");
        exit(DefaultUrl);
    end;

    /// <summary>
    /// Returns the argument's Model, or the provider default when blank.
    /// </summary>
    internal procedure GetModel(var Argument: Record "Bifrost Chat Argument ori" temporary; DefaultModel: Text): Text
    begin
        if Argument.Model <> '' then
            exit(Argument.Model);
        exit(DefaultModel);
    end;

    /// <summary>
    /// Returns the argument's timeout in milliseconds, or the provider default when zero.
    /// </summary>
    internal procedure GetTimeoutMs(var Argument: Record "Bifrost Chat Argument ori" temporary; DefaultMs: Integer): Integer
    begin
        if Argument."Timeout Ms" > 0 then
            exit(Argument."Timeout Ms");
        exit(DefaultMs);
    end;

    /// <summary>
    /// Returns the argument's max tokens, or the provider default when zero.
    /// </summary>
    internal procedure GetMaxTokens(var Argument: Record "Bifrost Chat Argument ori" temporary; DefaultMaxTokens: Integer): Integer
    begin
        if Argument."Max Tokens" > 0 then
            exit(Argument."Max Tokens");
        exit(DefaultMaxTokens);
    end;

    /// <summary>
    /// Returns whether the argument carries an API key and a resolvable Base URL.
    /// </summary>
    [NonDebuggable]
    internal procedure IsConfigured(var Argument: Record "Bifrost Chat Argument ori" temporary; DefaultBaseUrl: Text): Boolean
    begin
        if not Argument.HasApiKey() then
            exit(false);
        exit(GetBaseUrl(Argument, DefaultBaseUrl) <> '');
    end;

    /// <summary>
    /// Parses OpenAI-format token usage from a response JSON string.
    /// </summary>
    internal procedure ParseTokenUsage(ResponseJson: Text; var InputTokens: Integer; var OutputTokens: Integer)
    var
        ResponseObject: JsonObject;
        UsageToken: JsonToken;
        UsageObject: JsonObject;
        PromptToken: JsonToken;
        CompletionToken: JsonToken;
    begin
        InputTokens := 0;
        OutputTokens := 0;
        if not ResponseObject.ReadFrom(ResponseJson) then
            exit;
        if not ResponseObject.Get('usage', UsageToken) then
            exit;
        if not UsageToken.IsObject() then
            exit;
        UsageObject := UsageToken.AsObject();
        if UsageObject.Get('prompt_tokens', PromptToken) then
            InputTokens := PromptToken.AsValue().AsInteger();
        if UsageObject.Get('completion_tokens', CompletionToken) then
            OutputTokens := CompletionToken.AsValue().AsInteger();
    end;

    /// <summary>
    /// Returns whether any Bifrost Language Model is configured with an external chat provider.
    /// </summary>
    internal procedure HasServiceGate(): Boolean
    var
        BifrostLanguageModel: Record "Bifrost Language Model ori";
    begin
        BifrostLanguageModel.SetFilter("Chat Provider", '<>%1', BifrostLanguageModel."Chat Provider"::None);
        exit(not BifrostLanguageModel.IsEmpty());
    end;

    /// <summary>
    /// Asserts that a language model with a chat provider exists; responds with error if not.
    /// </summary>
    internal procedure AssertServiceGate(var Argument: Record "Message Argument ori"): Boolean
    begin
        if HasServiceGate() then
            exit(true);
        Argument.RespondWithError(ServiceGateDeniedErr);
        exit(false);
    end;

    /// <summary>
    /// Raises an error if HttpClient is not allowed in this environment.
    /// </summary>
    internal procedure EnsureHttpClientAllowed()
    begin
        if not CanSendHttpRequests() then
            Error(HttpClientBlockedMsg);
    end;

    local procedure CanSendHttpRequests(): Boolean
    var
        Handled: Boolean;
        Allowed: Boolean;
    begin
        OnCheckHttpClientAllowed(Handled, Allowed);
        if Handled then
            exit(Allowed);
        exit(true);
    end;

    [IntegrationEvent(false, false)]
    local procedure OnCheckHttpClientAllowed(var Handled: Boolean; var Allowed: Boolean)
    begin
    end;

    /// <summary>
    /// If the payload contains a files array, converts the last user message
    /// from plain text to a multi-modal content array (OpenAI format).
    /// </summary>
    internal procedure AttachFilesToMessages(PayloadObject: JsonObject; var Messages: JsonArray)
    var
        FilesToken: JsonToken;
        FilesArray: JsonArray;
        FileToken: JsonToken;
        ContentArray: JsonArray;
        TextBlock: JsonObject;
        FileBlock: JsonObject;
        LastToken: JsonToken;
        LastMessage: JsonObject;
        NewMessage: JsonObject;
        UserText: Text;
        LastIndex: Integer;
    begin
        if not PayloadObject.Get('files', FilesToken) then
            exit;
        if not FilesToken.IsArray() then
            exit;
        FilesArray := FilesToken.AsArray();
        if FilesArray.Count() = 0 then
            exit;

        LastIndex := Messages.Count() - 1;
        if LastIndex < 0 then
            exit;
        Messages.Get(LastIndex, LastToken);
        if not LastToken.IsObject() then
            exit;
        LastMessage := LastToken.AsObject();

        UserText := GetJsonTextInternal(LastMessage, 'content');
        TextBlock.Add('type', 'text');
        TextBlock.Add('text', UserText);
        ContentArray.Add(TextBlock);

        foreach FileToken in FilesArray do
            if FileToken.IsObject() then begin
                FileBlock := BuildOpenAIFileBlock(FileToken.AsObject());
                ContentArray.Add(FileBlock);
                Clear(FileBlock);
            end;

        // Replace the last message — JsonArray.Get returns a copy, not a reference
        Messages.RemoveAt(LastIndex);
        NewMessage.Add('role', 'user');
        NewMessage.Add('content', ContentArray);
        Messages.Add(NewMessage);
    end;

    local procedure BuildOpenAIFileBlock(FileObj: JsonObject) Block: JsonObject
    var
        DataUriTok: Label 'data:%1;base64,%2', Locked = true;
        ImageUrl: JsonObject;
        FileContent: JsonObject;
        MimeType: Text;
        DataUri: Text;
    begin
        MimeType := GetJsonTextInternal(FileObj, 'mimeType');
        DataUri := StrSubstNo(DataUriTok, MimeType, GetJsonTextInternal(FileObj, 'data'));

        if MimeType.StartsWith('image/') then begin
            ImageUrl.Add('url', DataUri);
            Block.Add('type', 'image_url');
            Block.Add('image_url', ImageUrl);
        end else begin
            FileContent.Add('filename', GetJsonTextInternal(FileObj, 'fileName'));
            FileContent.Add('file_data', DataUri);
            Block.Add('type', 'file');
            Block.Add('file', FileContent);
        end;
    end;

    local procedure GetJsonTextInternal(JObject: JsonObject; PropertyName: Text): Text
    var
        JToken: JsonToken;
    begin
        if JObject.Get(PropertyName, JToken) then
            if JToken.IsValue() then
                exit(JToken.AsValue().AsText());
    end;
}
