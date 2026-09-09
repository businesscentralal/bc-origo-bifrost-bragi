namespace Origo.Bifrost.LanguageModels;
using Microsoft.Utilities;
using Origo.Bifrost;

/// <summary>
/// Google Gemini provider. Uses OpenAI-compatible endpoint for text chat
/// and native generateContent API for file/document processing.
/// </summary>
codeunit 10035419 "Gemini LangModel Prov. ori" implements "Bifrost LangModel Provider ori"
{
    Access = Internal;

    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        AuthHeaderNameTok: Label 'Authorization', Locked = true;
        DefaultBaseUrlTok: Label 'https://generativelanguage.googleapis.com/v1beta', Locked = true;
        DefaultModelTok: Label 'gemini-2.5-flash', Locked = true;
        ProviderNameTok: Label 'Google', Locked = true;
        ApiKeyLabelLbl: Label 'API Key', Comment = 'is-IS=API-lykill';
        ApiKeyInstructionLbl: Label 'Enter your Google AI API key.', Comment = 'is-IS=Sláðu inn Google AI API-lykilinn þinn.';
        ApiKeyPlaceholderTok: Label 'AIza...', Locked = true;
        ApiKeyHeaderTok: Label 'x-goog-api-key', Locked = true;
        ApiKeyDocsUrlTok: Label 'https://aistudio.google.com/apikey', Locked = true;
        ApiKeyDocsLinkTextLbl: Label 'Get key from Google AI Studio', Comment = 'is-IS=Sækja lykil á Google AI Studio';
        ServiceKeyDescLbl: Label 'Shared keys are used by all users in this company who do not have a personal key.', Comment = 'is-IS=Sameiginlegir lyklar eru notaðir af öllum notendum í þessu fyrirtæki sem hafa ekki persónulegan lykil.';
        CallFailedErr: Label 'Could not reach the Google AI API. %1', Comment = '%1 = error detail, is-IS=Náði ekki sambandi við Google AI API. %1';
        ApiStatusErr: Label 'Google AI API returned status %1. %2', Comment = '%1 = status code, %2 = detail, is-IS=Google AI API skilaði stöðu %1. %2';

    procedure Execute(var Argument: Record "Bifrost Chat Argument ori" temporary)
    var
        ProcType: Enum "Bifrost Chat Proc. Type ori";
    begin
        ProcType := Argument."Procedure Type";
        case ProcType of
            ProcType::IsConfigured:
                Argument."Result Boolean" := ProviderBase.IsConfigured(Argument, DefaultBaseUrlTok);
            ProcType::BuildConfigJson:
                Argument.SetResultText(DoBuildConfigJson(Argument));
            ProcType::SendChatMessage:
                Argument.SetResultText(DoSendChatMessage(Argument));
            ProcType::CompletePrompt:
                Argument.SetResultText(DoCompletePrompt(Argument));
            ProcType::ContinueWithToolResults:
                Argument.SetResultText(DoContinueWithToolResults(Argument));
            ProcType::GetAvailableModels:
                Argument."Result Boolean" := DoGetAvailableModels(Argument);
            ProcType::TestConnection:
                Argument."Result Boolean" := DoTestConnection(Argument);
            ProcType::GetTokenUsage:
                DoGetTokenUsage(Argument);
            ProcType::GetProviderName:
                Argument.SetResultText(ProviderNameTok);
            ProcType::RequiresApiKey:
                Argument."Result Boolean" := true;
            ProcType::GetApiKeyLabel:
                Argument.SetResultText(ApiKeyLabelLbl);
            ProcType::GetApiKeyInstruction:
                Argument.SetResultText(ApiKeyInstructionLbl);
            ProcType::GetApiKeyPlaceholder:
                Argument.SetResultText(ApiKeyPlaceholderTok);
            ProcType::GetApiKeyDocsUrl:
                Argument.SetResultText(ApiKeyDocsUrlTok);
            ProcType::GetApiKeyDocsLinkText:
                Argument.SetResultText(ApiKeyDocsLinkTextLbl);
            ProcType::GetServiceKeyDescription:
                Argument.SetResultText(ServiceKeyDescLbl);
            ProcType::HasServiceKeyPermission:
                Argument."Result Boolean" := ProviderBase.HasServiceKeyPermission();
            ProcType::GetMaxToolCount:
                Argument."Result Integer" := 0;
            ProcType::SupportsSplitToolExecution:
                Argument."Result Boolean" := true;
            ProcType::SupportsModelSelection:
                Argument."Result Boolean" := true;
            ProcType::SupportsToolCalling:
                Argument."Result Boolean" := true;
            ProcType::HasExternalEndpoint:
                Argument."Result Boolean" := true;
            ProcType::GetDefaultBaseUrl:
                Argument.SetResultText(DefaultBaseUrlTok);
            ProcType::GetDefaultModel:
                Argument.SetResultText(DefaultModelTok);
            ProcType::GetDefaultTimeoutSeconds:
                Argument."Result Integer" := 120;
            ProcType::GetDefaultMaxTokens:
                Argument."Result Integer" := 16384;
            ProcType::GetContextWindowChars:
                Argument."Result Integer" := 800000;
            ProcType::GetDefaultSkillUrl:
                Argument.SetResultText('');
            ProcType::GetDefaultSkillText:
                Argument.SetResultText('');
        end;
    end;

    [NonDebuggable]
    local procedure DoBuildConfigJson(var Argument: Record "Bifrost Chat Argument ori" temporary): Text
    var
        ConfigJson: JsonObject;
        ConfigText: Text;
    begin
        ProviderBase.EnsureHttpClientAllowed();
        ConfigJson.Add('provider', ProviderNameTok);
        ConfigJson.Add('apiKey', Argument.GetApiKeyIndicator());
        ConfigJson.Add('model', ProviderBase.GetModel(Argument, DefaultModelTok));
        ConfigJson.Add('baseUrl', ProviderBase.GetBaseUrl(Argument, DefaultBaseUrlTok));
        ConfigJson.Add('timeoutMs', ProviderBase.GetTimeoutMs(Argument, 120000));
        ConfigJson.Add('maxTokens', ProviderBase.GetMaxTokens(Argument, 16384));
        ConfigJson.WriteTo(ConfigText);
        exit(ConfigText);
    end;

    // Chat uses Google's OpenAI-compatible endpoint
    local procedure DoSendChatMessage(var Argument: Record "Bifrost Chat Argument ori" temporary): Text
    var
        LangModelChatProxy: Codeunit "LangModel Chat Proxy ori";
    begin
        Argument."Base URL" := CopyStr(GetOpenAICompatBaseUrl(Argument), 1, MaxStrLen(Argument."Base URL"));
        exit(LangModelChatProxy.SendChatMessage(Argument, Argument.GetPayload(), AuthHeaderNameTok, BuildGeminiExtraFields()));
    end;

    local procedure DoContinueWithToolResults(var Argument: Record "Bifrost Chat Argument ori" temporary): Text
    var
        LangModelChatProxy: Codeunit "LangModel Chat Proxy ori";
    begin
        Argument."Base URL" := CopyStr(GetOpenAICompatBaseUrl(Argument), 1, MaxStrLen(Argument."Base URL"));
        exit(LangModelChatProxy.ContinueWithToolResults(Argument, Argument.GetConversationState(), Argument.GetToolResults(), AuthHeaderNameTok, BuildGeminiExtraFields()));
    end;

    // Force text-only responses so Gemini doesn't return audio/mpeg or other modalities the OpenAI-compat layer can't map.
    // Google's OpenAI-compat layer reads Gemini-native config from extra_body.google.*.
    local procedure BuildGeminiExtraFields() ExtraFields: JsonObject
    var
        GoogleObj: JsonObject;
        GenerationConfig: JsonObject;
        Modalities: JsonArray;
        ExtraBody: JsonObject;
    begin
        Modalities.Add('TEXT');
        GenerationConfig.Add('response_modalities', Modalities);
        GoogleObj.Add('generation_config', GenerationConfig);
        ExtraBody.Add('google', GoogleObj);
        ExtraFields.Add('extra_body', ExtraBody);
    end;

    [NonDebuggable]
    local procedure DoCompletePrompt(var Argument: Record "Bifrost Chat Argument ori" temporary): Text
    var
        PayloadObject: JsonObject;
    begin
        if not PayloadObject.ReadFrom(Argument.GetPayload()) then
            exit(BuildErrorJson('Invalid payload JSON.'));

        if HasFiles(PayloadObject) then
            exit(DoCompleteWithGenerateContent(Argument, PayloadObject))
        else
            exit(DoCompleteWithChatCompletions(Argument, PayloadObject));
    end;

    // Text-only: OpenAI-compatible /v1/chat/completions
    [NonDebuggable]
    local procedure DoCompleteWithChatCompletions(var Argument: Record "Bifrost Chat Argument ori" temporary; PayloadObject: JsonObject): Text
    var
        ApiClient: Codeunit "LangModel API Client ori";
        RequestBody: JsonObject;
        Messages: JsonArray;
        SystemMsg: JsonObject;
        Response: JsonObject;
        ResponseObj: JsonObject;
        SystemPrompt: Text;
        ChatUrl: Text;
        ResultText: Text;
    begin
        ProviderBase.EnsureHttpClientAllowed();
        SystemPrompt := GetJsonText(PayloadObject, 'systemPrompt');
        if SystemPrompt <> '' then begin
            SystemMsg.Add('role', 'system');
            SystemMsg.Add('content', SystemPrompt);
            Messages.Add(SystemMsg);
        end;
        AppendPayloadMessages(PayloadObject, Messages);

        RequestBody.Add('model', ProviderBase.GetModel(Argument, DefaultModelTok));
        RequestBody.Add('max_completion_tokens', ProviderBase.GetMaxTokens(Argument, 16384));
        RequestBody.Add('messages', Messages);

        ChatUrl := GetOpenAICompatBaseUrl(Argument) + '/chat/completions';
        Response := ApiClient.SendToEndpoint(ChatUrl, AuthHeaderNameTok, Argument.GetApiKey(),
            ProviderBase.GetTimeoutMs(Argument, 120000), RequestBody);
        ApiClient.LogLastRequest();

        ResponseObj.Add('reply', ApiClient.ExtractText(Response));
        ResponseObj.WriteTo(ResultText);
        exit(ResultText);
    end;

    // Files: native Gemini generateContent API
    [NonDebuggable]
    local procedure DoCompleteWithGenerateContent(var Argument: Record "Bifrost Chat Argument ori" temporary; PayloadObject: JsonObject): Text
    var
        RequestBody: JsonObject;
        Contents: JsonArray;
        ContentObj: JsonObject;
        Parts: JsonArray;
        TextPart: JsonObject;
        SystemInstruction: JsonObject;
        SystemParts: JsonArray;
        SystemTextPart: JsonObject;
        GenConfig: JsonObject;
        Response: JsonObject;
        ResponseObj: JsonObject;
        SystemPrompt: Text;
        UserPrompt: Text;
        GenerateUrl: Text;
        ResultText: Text;
        GenerateUrlTok: Label '%1/models/%2:generateContent', Locked = true;
    begin
        ProviderBase.EnsureHttpClientAllowed();
        UserPrompt := GetFirstUserMessage(PayloadObject);

        AddFilesAsInlineData(PayloadObject, Parts);

        Clear(TextPart);
        TextPart.Add('text', UserPrompt);
        Parts.Add(TextPart);

        ContentObj.Add('parts', Parts);
        Contents.Add(ContentObj);
        RequestBody.Add('contents', Contents);

        SystemPrompt := GetJsonText(PayloadObject, 'systemPrompt');
        if SystemPrompt <> '' then begin
            SystemTextPart.Add('text', SystemPrompt);
            SystemParts.Add(SystemTextPart);
            SystemInstruction.Add('parts', SystemParts);
            RequestBody.Add('systemInstruction', SystemInstruction);
        end;

        GenConfig.Add('maxOutputTokens', ProviderBase.GetMaxTokens(Argument, 16384));
        RequestBody.Add('generationConfig', GenConfig);

        GenerateUrl := StrSubstNo(GenerateUrlTok,
            GetNativeBaseUrl(Argument),
            StripModelsPrefix(ProviderBase.GetModel(Argument, DefaultModelTok)));

        Response := SendGenerateContent(GenerateUrl, Argument.GetApiKey(),
            ProviderBase.GetTimeoutMs(Argument, 120000), RequestBody);

        ResponseObj.Add('reply', ExtractGenerateContentText(Response));
        ResponseObj.WriteTo(ResultText);
        exit(ResultText);
    end;

    local procedure AddFilesAsInlineData(PayloadObject: JsonObject; var Parts: JsonArray)
    var
        FilesToken: JsonToken;
        FileToken: JsonToken;
        FileObj: JsonObject;
        InlineData: JsonObject;
        FilePart: JsonObject;
    begin
        if not PayloadObject.Get('files', FilesToken) then
            exit;
        foreach FileToken in FilesToken.AsArray() do begin
            if not FileToken.IsObject() then
                continue;
            FileObj := FileToken.AsObject();
            Clear(InlineData);
            InlineData.Add('mime_type', GetJsonText(FileObj, 'mimeType'));
            InlineData.Add('data', GetJsonText(FileObj, 'data'));
            Clear(FilePart);
            FilePart.Add('inline_data', InlineData);
            Parts.Add(FilePart);
        end;
    end;

    local procedure ExtractGenerateContentText(Response: JsonObject): Text
    var
        CandidatesToken: JsonToken;
        FirstCandidate: JsonToken;
        ContentToken: JsonToken;
        PartsToken: JsonToken;
        FirstPart: JsonToken;
    begin
        if not Response.Get('candidates', CandidatesToken) then
            exit('');
        if not CandidatesToken.IsArray() then
            exit('');
        if CandidatesToken.AsArray().Count() = 0 then
            exit('');
        CandidatesToken.AsArray().Get(0, FirstCandidate);
        if not FirstCandidate.IsObject() then
            exit('');
        if not FirstCandidate.AsObject().Get('content', ContentToken) then
            exit('');
        if not ContentToken.IsObject() then
            exit('');
        if not ContentToken.AsObject().Get('parts', PartsToken) then
            exit('');
        if not PartsToken.IsArray() then
            exit('');
        if PartsToken.AsArray().Count() = 0 then
            exit('');
        PartsToken.AsArray().Get(0, FirstPart);
        if not FirstPart.IsObject() then
            exit('');
        exit(GetJsonText(FirstPart.AsObject(), 'text'));
    end;

    [NonDebuggable]
    local procedure SendGenerateContent(Url: Text; ApiKey: SecretText; TimeoutMs: Integer; RequestBody: JsonObject) Response: JsonObject
    var
        HttpClientVar: HttpClient;
        HttpContent: HttpContent;
        HttpResponse: HttpResponseMessage;
        ContentHeaders: HttpHeaders;
        DefaultHeaders: HttpHeaders;
        RequestText: Text;
        ResponseText: Text;
        StartTime: DateTime;
    begin
        RequestBody.WriteTo(RequestText);
        HttpContent.WriteFrom(RequestText);
        HttpContent.GetHeaders(ContentHeaders);
        if ContentHeaders.Contains('Content-Type') then
            ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'application/json');
        DefaultHeaders := HttpClientVar.DefaultRequestHeaders();
        DefaultHeaders.Add(ApiKeyHeaderTok, ApiKey);
        HttpClientVar.Timeout(TimeoutMs);

        StartTime := CurrentDateTime();
        if not HttpClientVar.Post(Url, HttpContent, HttpResponse) then
            Error(CallFailedErr, GetLastErrorText());

        HttpResponse.Content.ReadAs(ResponseText);
        if not HttpResponse.IsSuccessStatusCode() then
            Error(ApiStatusErr, Format(HttpResponse.HttpStatusCode()), GetErrorDetail(ResponseText));

        if not Response.ReadFrom(ResponseText) then
            Error(CallFailedErr, 'Invalid response JSON.');

        LogApiCall('generateContent', 'POST', Url,
            HttpResponse.HttpStatusCode(), CurrentDateTime() - StartTime, RequestText, ResponseText);
    end;

    local procedure GetOpenAICompatBaseUrl(var Argument: Record "Bifrost Chat Argument ori" temporary): Text
    var
        BaseUrl: Text;
    begin
        BaseUrl := GetNativeBaseUrl(Argument);
        if not BaseUrl.EndsWith('/openai') then
            BaseUrl += '/openai';
        exit(BaseUrl);
    end;

    /// <summary>
    /// Strips /openai suffix if present — returns the base for native Gemini API calls.
    /// </summary>
    local procedure GetNativeBaseUrl(var Argument: Record "Bifrost Chat Argument ori" temporary): Text
    var
        BaseUrl: Text;
    begin
        BaseUrl := ProviderBase.GetBaseUrl(Argument, DefaultBaseUrlTok);
        if BaseUrl.EndsWith('/openai') then
            BaseUrl := CopyStr(BaseUrl, 1, StrLen(BaseUrl) - StrLen('/openai'));
        exit(BaseUrl);
    end;

    local procedure StripModelsPrefix(ModelName: Text): Text
    begin
        if ModelName.StartsWith('models/') then
            exit(CopyStr(ModelName, 8));
        exit(ModelName);
    end;

    local procedure HasFiles(PayloadObject: JsonObject): Boolean
    var
        FilesToken: JsonToken;
    begin
        if not PayloadObject.Get('files', FilesToken) then
            exit(false);
        exit(FilesToken.IsArray() and (FilesToken.AsArray().Count() > 0));
    end;

    local procedure GetFirstUserMessage(PayloadObject: JsonObject): Text
    var
        MessagesToken: JsonToken;
        MessageToken: JsonToken;
        MessageObject: JsonObject;
    begin
        if not PayloadObject.Get('messages', MessagesToken) then
            exit('');
        if not MessagesToken.IsArray() then
            exit('');
        foreach MessageToken in MessagesToken.AsArray() do begin
            if not MessageToken.IsObject() then
                continue;
            MessageObject := MessageToken.AsObject();
            if GetJsonText(MessageObject, 'role') = 'user' then
                exit(GetJsonText(MessageObject, 'content'));
        end;
    end;

    local procedure DoGetAvailableModels(var Argument: Record "Bifrost Chat Argument ori" temporary): Boolean
    var
        TempNameValueBuffer: Record "Name/Value Buffer" temporary;
        HttpClientVar: HttpClient;
        HttpResponse: HttpResponseMessage;
        DefaultHeaders: HttpHeaders;
        Response: JsonObject;
        ModelsToken: JsonToken;
        ModelToken: JsonToken;
        ModelObject: JsonObject;
        ResponseText: Text;
        ModelsUrl: Text;
        IdValue: Text;
        EntryNo: Integer;
        ModelsUrlTok: Label '%1/models', Locked = true;
    begin
        ModelsUrl := StrSubstNo(ModelsUrlTok, GetNativeBaseUrl(Argument));

        DefaultHeaders := HttpClientVar.DefaultRequestHeaders();
        DefaultHeaders.Add(ApiKeyHeaderTok, Argument.GetApiKey());
        HttpClientVar.Timeout(15000);
        if not HttpClientVar.Get(ModelsUrl, HttpResponse) then begin
            Argument.SetErrorMessage(StrSubstNo(CallFailedErr, 'The request could not be sent.'));
            exit(false);
        end;
        HttpResponse.Content.ReadAs(ResponseText);
        if not HttpResponse.IsSuccessStatusCode() then begin
            Argument.SetErrorMessage(StrSubstNo(ApiStatusErr, Format(HttpResponse.HttpStatusCode()), GetErrorDetail(ResponseText)));
            exit(false);
        end;
        if not Response.ReadFrom(ResponseText) then begin
            Argument.SetErrorMessage(StrSubstNo(CallFailedErr, 'Invalid response JSON.'));
            exit(false);
        end;
        if not Response.Get('models', ModelsToken) then begin
            Argument.SetErrorMessage(StrSubstNo(CallFailedErr, GetErrorDetail(ResponseText)));
            exit(false);
        end;
        if not ModelsToken.IsArray() then begin
            Argument.SetErrorMessage(StrSubstNo(CallFailedErr, 'The model list was not an array.'));
            exit(false);
        end;

        foreach ModelToken in ModelsToken.AsArray() do begin
            if not ModelToken.IsObject() then
                continue;
            ModelObject := ModelToken.AsObject();
            IdValue := GetJsonText(ModelObject, 'name');
            if IdValue.StartsWith('models/') then
                IdValue := CopyStr(IdValue, 8);
            if IdValue <> '' then begin
                EntryNo += 1;
                TempNameValueBuffer.Init();
                TempNameValueBuffer.ID := EntryNo;
                TempNameValueBuffer.Name := CopyStr(IdValue, 1, MaxStrLen(TempNameValueBuffer.Name));
                TempNameValueBuffer.Value := CopyStr(IdValue, 1, MaxStrLen(TempNameValueBuffer.Value));
                TempNameValueBuffer.Insert();
            end;
        end;
        Argument.SetModels(TempNameValueBuffer);
        if EntryNo = 0 then begin
            Argument.SetErrorMessage(StrSubstNo(CallFailedErr, 'The API key is valid but no models were returned.'));
            exit(false);
        end;
        exit(true);
    end;

    local procedure DoTestConnection(var Argument: Record "Bifrost Chat Argument ori" temporary): Boolean
    var
        NoKeyErr: Label 'No API key configured. Enter a personal or shared API key.', Comment = 'is-IS=Enginn API-lykill stilltur. Sláðu inn persónulegan eða sameiginlegan API-lykil.';
    begin
        if not Argument.HasApiKey() then begin
            Argument.SetErrorMessage(NoKeyErr);
            exit(false);
        end;
        exit(DoGetAvailableModels(Argument));
    end;

    local procedure DoGetTokenUsage(var Argument: Record "Bifrost Chat Argument ori" temporary)
    begin
        Argument."Input Tokens" := 0;
        Argument."Output Tokens" := 0;
    end;

    local procedure AppendPayloadMessages(PayloadObject: JsonObject; var Messages: JsonArray)
    var
        MessagesToken: JsonToken;
        MessageToken: JsonToken;
    begin
        if not PayloadObject.Get('messages', MessagesToken) then
            exit;
        if not MessagesToken.IsArray() then
            exit;
        foreach MessageToken in MessagesToken.AsArray() do
            Messages.Add(MessageToken);
    end;

    local procedure BuildErrorJson(ErrorMessage: Text): Text
    var
        ErrorObj: JsonObject;
        Result: Text;
    begin
        ErrorObj.Add('error', ErrorMessage);
        ErrorObj.WriteTo(Result);
        exit(Result);
    end;

    local procedure GetErrorDetail(ResponseText: Text): Text
    var
        ResponseArray: JsonArray;
        ResponseObject: JsonObject;
        ErrorToken: JsonToken;
        MessageToken: JsonToken;
        FirstItem: JsonToken;
    begin
        // Google returns [{error: {message: "..."}}] or {error: {message: "..."}}
        if ResponseArray.ReadFrom(ResponseText) then begin
            if ResponseArray.Count() > 0 then begin
                ResponseArray.Get(0, FirstItem);
                if FirstItem.IsObject() then begin
                    ResponseObject := FirstItem.AsObject();
                    if ResponseObject.Get('error', ErrorToken) then
                        if ErrorToken.IsObject() then
                            if ErrorToken.AsObject().Get('message', MessageToken) then
                                if MessageToken.IsValue() then
                                    exit(MessageToken.AsValue().AsText());
                end;
            end;
        end else
            if ResponseObject.ReadFrom(ResponseText) then
                if ResponseObject.Get('error', ErrorToken) then begin
                    if ErrorToken.IsValue() then
                        exit(ErrorToken.AsValue().AsText());
                    if ErrorToken.IsObject() then
                        if ErrorToken.AsObject().Get('message', MessageToken) then
                            if MessageToken.IsValue() then
                                exit(MessageToken.AsValue().AsText());
                end;
        exit(CopyStr(ResponseText, 1, 1000));
    end;

    local procedure GetJsonText(JObject: JsonObject; PropertyName: Text): Text
    var
        JToken: JsonToken;
    begin
        if JObject.Get(PropertyName, JToken) then
            if JToken.IsValue() then
                exit(JToken.AsValue().AsText());
    end;

    local procedure LogApiCall(Operation: Text[50]; HttpMethod: Text[10]; RequestUrl: Text; HttpStatus: Integer; Elapsed: Duration; RequestText: Text; ResponseText: Text)
    var
        Setup: Record "Setup ori";
        Logger: Codeunit "Request Logger ori";
        ServiceNameTok: Label 'LLM', Locked = true;
    begin
        Setup.SetLoadFields("Request Debug Mode");
        if not Setup.Get() then
            exit;
        if not Setup."Request Debug Mode" then
            exit;

        Logger.Log(Operation, HttpMethod, RequestUrl, ServiceNameTok,
            HttpStatus, Elapsed, true, '',
            RequestText, ResponseText,
            Enum::"Request Log Type ori"::"LLM");
        Logger.Insert();
    end;
}
