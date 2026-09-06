namespace Origo.Bifrost.Bragi;
using Microsoft.Utilities;
using Origo.Bifrost;

/// <summary>
/// xAI (Grok) provider. Uses Chat Completions for text and the
/// Responses API (/v1/responses) for file/document processing.
/// </summary>
codeunit 10035418 "xAI LangModel Prov. ori" implements "Bifrost LangModel Provider ori"
{
    Access = Internal;

    var
        ProviderBase: Codeunit "LangModel Prov. Base ori";
        AuthHeaderNameTok: Label 'Authorization', Locked = true;
        DefaultBaseUrlTok: Label 'https://api.x.ai', Locked = true;
        DefaultModelTok: Label 'grok-3', Locked = true;
        ProviderNameTok: Label 'xAI', Locked = true;
        ApiKeyLabelLbl: Label 'API Key', Comment = 'is-IS=API-lykill';
        ApiKeyInstructionLbl: Label 'Enter your xAI API key.', Comment = 'is-IS=Sláðu inn xAI API-lykilinn þinn.';
        ApiKeyPlaceholderTok: Label 'xai-...', Locked = true;
        ApiKeyDocsUrlTok: Label 'https://console.x.ai/', Locked = true;
        ApiKeyDocsLinkTextLbl: Label 'Get key from xAI Console', Comment = 'is-IS=Sækja lykil á xAI Console';
        ServiceKeyDescLbl: Label 'Shared keys are used by all users in this company who do not have a personal key.', Comment = 'is-IS=Sameiginlegir lyklar eru notaðir af öllum notendum í þessu fyrirtæki sem hafa ekki persónulegan lykil.';

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
                Argument."Result Integer" := 80000;
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

    local procedure DoSendChatMessage(var Argument: Record "Bifrost Chat Argument ori" temporary): Text
    var
        LangModelChatProxy: Codeunit "LangModel Chat Proxy ori";
    begin
        exit(LangModelChatProxy.SendChatMessage(Argument, Argument.GetPayload(), AuthHeaderNameTok));
    end;

    local procedure DoContinueWithToolResults(var Argument: Record "Bifrost Chat Argument ori" temporary): Text
    var
        LangModelChatProxy: Codeunit "LangModel Chat Proxy ori";
    begin
        exit(LangModelChatProxy.ContinueWithToolResults(Argument, Argument.GetConversationState(), Argument.GetToolResults(), AuthHeaderNameTok));
    end;

    [NonDebuggable]
    local procedure DoCompletePrompt(var Argument: Record "Bifrost Chat Argument ori" temporary): Text
    var
        PayloadObject: JsonObject;
    begin
        if not PayloadObject.ReadFrom(Argument.GetPayload()) then
            exit(BuildErrorJson('Invalid payload JSON.'));

        if HasFiles(PayloadObject) then
            exit(DoCompleteWithResponsesApi(Argument, PayloadObject))
        else
            exit(DoCompleteWithChatCompletions(Argument, PayloadObject));
    end;

    // Text-only: standard /v1/chat/completions (same as OpenAI)
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

        ChatUrl := ProviderBase.GetBaseUrl(Argument, DefaultBaseUrlTok) + '/v1/chat/completions';
        Response := ApiClient.SendToEndpoint(ChatUrl, AuthHeaderNameTok, Argument.GetApiKey(),
            ProviderBase.GetTimeoutMs(Argument, 120000), RequestBody);
        ApiClient.LogLastRequest();

        ResponseObj.Add('reply', ApiClient.ExtractText(Response));
        ResponseObj.WriteTo(ResultText);
        exit(ResultText);
    end;

    // Files present: xAI Responses API (/v1/responses)
    [NonDebuggable]
    local procedure DoCompleteWithResponsesApi(var Argument: Record "Bifrost Chat Argument ori" temporary; PayloadObject: JsonObject): Text
    var
        ApiClient: Codeunit "LangModel API Client ori";
        RequestBody: JsonObject;
        InputArray: JsonArray;
        InputMessage: JsonObject;
        ContentArray: JsonArray;
        TextBlock: JsonObject;
        Response: JsonObject;
        ResponseObj: JsonObject;
        SystemPrompt: Text;
        ResponsesUrl: Text;
        UserPrompt: Text;
        ResultText: Text;
    begin
        ProviderBase.EnsureHttpClientAllowed();
        UserPrompt := GetFirstUserMessage(PayloadObject);
        TextBlock.Add('type', 'input_text');
        TextBlock.Add('text', UserPrompt);
        ContentArray.Add(TextBlock);

        AddFilesToResponsesContent(PayloadObject, ContentArray);

        InputMessage.Add('role', 'user');
        InputMessage.Add('content', ContentArray);
        InputArray.Add(InputMessage);

        RequestBody.Add('model', ProviderBase.GetModel(Argument, DefaultModelTok));
        RequestBody.Add('input', InputArray);

        SystemPrompt := GetJsonText(PayloadObject, 'systemPrompt');
        if SystemPrompt <> '' then
            RequestBody.Add('instructions', SystemPrompt);

        RequestBody.Add('max_output_tokens', ProviderBase.GetMaxTokens(Argument, 16384));

        ResponsesUrl := ProviderBase.GetBaseUrl(Argument, DefaultBaseUrlTok) + '/v1/responses';
        Response := ApiClient.SendToEndpoint(ResponsesUrl, AuthHeaderNameTok, Argument.GetApiKey(),
            ProviderBase.GetTimeoutMs(Argument, 120000), RequestBody);
        ApiClient.LogLastRequest();

        ResponseObj.Add('reply', ExtractResponsesText(Response));
        ResponseObj.WriteTo(ResultText);
        exit(ResultText);
    end;

    local procedure AddFilesToResponsesContent(PayloadObject: JsonObject; var ContentArray: JsonArray)
    var
        DataUriTok: Label 'data:%1;base64,%2', Locked = true;
        FilesToken: JsonToken;
        FileToken: JsonToken;
        FileObj: JsonObject;
        FileBlock: JsonObject;
        MimeType: Text;
        DataUri: Text;
    begin
        if not PayloadObject.Get('files', FilesToken) then
            exit;
        foreach FileToken in FilesToken.AsArray() do begin
            if not FileToken.IsObject() then
                continue;
            FileObj := FileToken.AsObject();
            MimeType := GetJsonText(FileObj, 'mimeType');
            DataUri := StrSubstNo(DataUriTok, MimeType, GetJsonText(FileObj, 'data'));
            Clear(FileBlock);
            if MimeType.StartsWith('image/') then begin
                FileBlock.Add('type', 'input_image');
                FileBlock.Add('image_url', DataUri);
            end else begin
                FileBlock.Add('type', 'input_file');
                FileBlock.Add('file_data', DataUri);
                FileBlock.Add('filename', GetJsonText(FileObj, 'fileName'));
            end;
            ContentArray.Add(FileBlock);
        end;
    end;

    local procedure ExtractResponsesText(Response: JsonObject): Text
    var
        OutputToken: JsonToken;
        ItemToken: JsonToken;
        ItemObj: JsonObject;
        ContentToken: JsonToken;
        BlockToken: JsonToken;
        BlockObj: JsonObject;
    begin
        if not Response.Get('output', OutputToken) then
            exit('');
        if not OutputToken.IsArray() then
            exit('');
        foreach ItemToken in OutputToken.AsArray() do begin
            if not ItemToken.IsObject() then
                continue;
            ItemObj := ItemToken.AsObject();
            if GetJsonText(ItemObj, 'type') <> 'message' then
                continue;
            if not ItemObj.Get('content', ContentToken) then
                continue;
            if not ContentToken.IsArray() then
                continue;
            foreach BlockToken in ContentToken.AsArray() do begin
                if not BlockToken.IsObject() then
                    continue;
                BlockObj := BlockToken.AsObject();
                if GetJsonText(BlockObj, 'type') = 'output_text' then
                    exit(GetJsonText(BlockObj, 'text'));
            end;
        end;
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
        ApiClient: Codeunit "LangModel API Client ori";
        ModelsArray: JsonArray;
        ModelToken: JsonToken;
        ModelObject: JsonObject;
        BaseUrl: Text;
        IdValue: Text;
        EntryNo: Integer;
    begin
        BaseUrl := ProviderBase.GetBaseUrl(Argument, DefaultBaseUrlTok);
        ModelsArray := ApiClient.ListModelsFromEndpoint(BaseUrl + '/v1/models', AuthHeaderNameTok, Argument.GetApiKey());

        foreach ModelToken in ModelsArray do begin
            if not ModelToken.IsObject() then
                continue;
            ModelObject := ModelToken.AsObject();
            IdValue := GetJsonText(ModelObject, 'id');
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
        exit(EntryNo > 0);
    end;

    local procedure DoTestConnection(var Argument: Record "Bifrost Chat Argument ori" temporary): Boolean
    var
        ApiClient: Codeunit "LangModel API Client ori";
        BaseUrl: Text;
        NoKeyErr: Label 'No API key configured. Enter a personal or shared API key.', Comment = 'is-IS=Enginn API-lykill stilltur. Sláðu inn persónulegan eða sameiginlegan API-lykil.';
    begin
        if not Argument.HasApiKey() then begin
            Argument.SetErrorMessage(NoKeyErr);
            exit(false);
        end;
        BaseUrl := ProviderBase.GetBaseUrl(Argument, DefaultBaseUrlTok);
        ApiClient.ListModelsFromEndpoint(BaseUrl + '/v1/models', AuthHeaderNameTok, Argument.GetApiKey());
        exit(true);
    end;

    local procedure DoGetTokenUsage(var Argument: Record "Bifrost Chat Argument ori" temporary)
    var
        InTokens: Integer;
        OutTokens: Integer;
    begin
        ProviderBase.ParseTokenUsage(Argument.GetPayload(), InTokens, OutTokens);
        Argument."Input Tokens" := InTokens;
        Argument."Output Tokens" := OutTokens;
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

    local procedure GetJsonText(JObject: JsonObject; PropertyName: Text): Text
    var
        JToken: JsonToken;
    begin
        if JObject.Get(PropertyName, JToken) then
            if JToken.IsValue() then
                exit(JToken.AsValue().AsText());
    end;
}
