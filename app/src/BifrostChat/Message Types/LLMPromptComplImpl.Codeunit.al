namespace Origo.Bifrost.Bragi;
using Microsoft.EServices.EDocument;

using Microsoft.Foundation.Attachment;
using Origo.Bifrost;
using System.Text;
using System.Utilities;

/// <summary>
/// One-shot LLM completion. Sends system + user prompt to the configured provider
/// and returns the text response. No tools, no chat Bootstrap, no conversation state.
/// </summary>
codeunit 10035396 "LLM Prompt Compl Impl ori" implements "Msg Interface ori"
{
    Access = Internal;

    var
        MissingPromptErr: Label 'The "prompt" field is required.', Comment = 'is-IS=Reiturinn "prompt" er nauðsynlegur.';
        NoProviderErr: Label 'No chat provider configured. Set up a Bifrost Language Model with a Chat Provider.', Comment = 'is-IS=Enginn spjallveitandi stilltur. Settu upp Bifröst mállíkan með spjallveitanda.';
        RoleNotFoundErr: Label 'Bifrost Language Model "%1" not found.', Comment = '%1 = role code, is-IS=Bifröst mállíkan "%1" fannst ekki.';

    internal procedure IsEnabled(): Boolean
    begin
        exit(true);
    end;

    internal procedure GetFilterTableNo(): Integer
    begin
        exit(0);
    end;

    internal procedure GetDescription() Description: Text[250]
    var
        DescriptionLbl: Label 'One-shot LLM completion — send a prompt, get text back. No tools, no chat.', Comment = 'is-IS=Einskots LLM framkvæmd — senda kvaðningu, fá texta til baka. Engin tól, ekkert spjall.';
    begin
        exit(DescriptionLbl);
    end;

    internal procedure GetMessageDirection(): Enum "Msg Direction ori"
    begin
        exit(Enum::"Msg Direction ori"::Outbound);
    end;

    internal procedure GetMessageHelpAsMarkdownDocument(var Argument: Record "Message Argument ori")
    var
        HelpCodeunit: Codeunit "LLM Prompt Compl Help ori";
    begin
        Argument.SetResponseMarkdown(HelpCodeunit.GetHelpText());
    end;

    [NonDebuggable]
    internal procedure ExecuteBifrostTask(var Argument: Record "Message Argument ori")
    var
        BifrostLanguageModel: Record "Bifrost Language Model ori";
        TempChatArg: Record "Bifrost Chat Argument ori" temporary;
        ChatMgt: Codeunit "Bifrost Chat Mgt ori";
        Provider: Interface "Bifrost LangModel Provider ori";
        RequestJson: JsonObject;
        PayloadJson: JsonObject;
        MessagesArray: JsonArray;
        MessageObj: JsonObject;
        ResponseJson: JsonObject;
        ResponseText: Text;
        SystemPrompt: Text;
        UserPrompt: Text;
        RoleCode: Code[20];
        PromptDeniedErr: Label 'LLM prompt denied: missing ''Bifrost Chat'' permission set.', Comment = 'is-IS=LLM kvaðningu hafnað: vantar ''Bifröst Chat'' heimildasett.';
    begin
        Argument.AssertVersion1();
        Argument.AssertIsLicensed();

        if not ChatMgt.HasChatPermission() then begin
            Argument.RespondWithError(PromptDeniedErr);
            exit;
        end;

        RequestJson := Argument.GetRequestJson();
        UserPrompt := GetTextValue(RequestJson, 'prompt');
        if UserPrompt = '' then begin
            Argument.RespondWithError(MissingPromptErr);
            exit;
        end;

        RoleCode := CopyStr(GetTextValue(RequestJson, 'roleCode'), 1, MaxStrLen(RoleCode));
        if (RoleCode <> '') and (not BifrostLanguageModel.Get(RoleCode)) then begin
            Argument.RespondWithError(StrSubstNo(RoleNotFoundErr, RoleCode));
            exit;
        end;

        if RoleCode <> '' then
            Provider := BifrostLanguageModel."Chat Provider"
        else
            Provider := ChatMgt.GetLangModelProviderWithModel(BifrostLanguageModel);
        BuildChatArgument(BifrostLanguageModel, TempChatArg);
        TempChatArg."Procedure Type" := TempChatArg."Procedure Type"::IsConfigured;
        Provider.Execute(TempChatArg);
        if not TempChatArg."Result Boolean" then begin
            Argument.RespondWithError(NoProviderErr);
            exit;
        end;

        SystemPrompt := GetTextValue(RequestJson, 'system');
        if SystemPrompt <> '' then
            PayloadJson.Add('systemPrompt', SystemPrompt);

        MessageObj.Add('role', 'user');
        MessageObj.Add('content', UserPrompt);
        MessagesArray.Add(MessageObj);
        PayloadJson.Add('messages', MessagesArray);
        AddFileContent(RequestJson, PayloadJson);

        PayloadJson.WriteTo(ResponseText);
        TempChatArg.SetPayload(ResponseText);
        TempChatArg."Procedure Type" := TempChatArg."Procedure Type"::CompletePrompt;
        TempChatArg.SetResultText('');
        Provider.Execute(TempChatArg);
        ResponseText := TempChatArg.GetResultText();

        if not ResponseJson.ReadFrom(ResponseText) then begin
            Argument.RespondWithError(ResponseText);
            exit;
        end;

        if HasProperty(ResponseJson, 'error') then begin
            Argument.RespondWithError(GetTextValue(ResponseJson, 'error'));
            exit;
        end;

        ResponseJson.Add('status', 'Success');
        if not HasProperty(ResponseJson, 'text') then
            if HasProperty(ResponseJson, 'reply') then
                ResponseJson.Add('text', GetTextValue(ResponseJson, 'reply'));

        Argument.SetResponseJson(ResponseJson);
        Argument."Content Type" := Argument.GetContentTypeJson();
    end;

    local procedure GetTextValue(Source: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if Source.Get(PropertyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsText());
        exit('');
    end;

    local procedure HasProperty(Source: JsonObject; PropertyName: Text): Boolean
    var
        Token: JsonToken;
    begin
        exit(Source.Get(PropertyName, Token));
    end;

    [NonDebuggable]
    local procedure BuildChatArgument(var BifrostLanguageModel: Record "Bifrost Language Model ori"; var TempChatArg: Record "Bifrost Chat Argument ori" temporary)
    var
        UserKeyTok: Label 'Bifrost_Chat_Usr_', Locked = true;
        ServiceKeyTok: Label 'Bifrost_Chat_Svc_', Locked = true;
        ApiKeyValue: Text;
    begin
        TempChatArg.Init();
        TempChatArg."Language Model SystemId" := BifrostLanguageModel.SystemId;
        TempChatArg."Base URL" := BifrostLanguageModel."Base URL";
        TempChatArg.Model := BifrostLanguageModel.Model;
        TempChatArg."Timeout Ms" := BifrostLanguageModel."Timeout Seconds" * 1000;
        TempChatArg."Max Tokens" := BifrostLanguageModel."Max Tokens";
        if IsolatedStorage.Get(UserKeyTok + Format(BifrostLanguageModel.SystemId, 0, 4) + '_' + Format(UserSecurityId(), 0, 4), DataScope::Company, ApiKeyValue) then
            if ApiKeyValue <> '' then begin
                TempChatArg.SetApiKey(ApiKeyValue);
                exit;
            end;
        if IsolatedStorage.Get(ServiceKeyTok + Format(BifrostLanguageModel.SystemId, 0, 4), DataScope::Company, ApiKeyValue) then
            TempChatArg.SetApiKey(ApiKeyValue);
    end;

    local procedure AddFileContent(RequestJson: JsonObject; var PayloadJson: JsonObject)
    var
        FileToken: JsonToken;
        AttachmentToken: JsonToken;
        FileJson: JsonObject;
        FilesArray: JsonArray;
    begin
        if RequestJson.Get('file', FileToken) then begin
            if FileToken.IsObject() then begin
                FilesArray.Add(FileToken);
                PayloadJson.Add('files', FilesArray);
            end;
            exit;
        end;

        if RequestJson.Get('attachment', AttachmentToken) then
            if AttachmentToken.IsObject() then
                if ResolveAttachment(AttachmentToken.AsObject(), FileJson) then begin
                    FilesArray.Add(FileJson);
                    PayloadJson.Add('files', FilesArray);
                end;
    end;

    local procedure ResolveAttachment(AttachmentJson: JsonObject; var FileJson: JsonObject): Boolean
    var
        TableName: Text;
    begin
        TableName := GetTextValue(AttachmentJson, 'table');
        case TableName of
            'Incoming Document Attachment':
                exit(ResolveIncomingDocAttachment(AttachmentJson, FileJson));
            'Document Attachment':
                exit(ResolveDocumentAttachment(AttachmentJson, FileJson));
            else
                exit(false);
        end;
    end;

    local procedure ResolveIncomingDocAttachment(AttachmentJson: JsonObject; var FileJson: JsonObject): Boolean
    var
        IncomingDocAttachment: Record "Incoming Document Attachment";
        TempBlob: Codeunit "Temp Blob";
        Base64Convert: Codeunit "Base64 Convert";
        InStream: InStream;
        SystemIdGuid: Guid;
        FileName: Text;
    begin
        if not Evaluate(SystemIdGuid, GetTextValue(AttachmentJson, 'systemId')) then
            exit(false);
        IncomingDocAttachment.SetLoadFields(Name, "File Extension", Content);
        if not IncomingDocAttachment.GetBySystemId(SystemIdGuid) then
            exit(false);
        if not IncomingDocAttachment.GetContent(TempBlob) then
            exit(false);
        TempBlob.CreateInStream(InStream);
        FileName := IncomingDocAttachment.Name;
        if (FileName <> '') and (IncomingDocAttachment."File Extension" <> '') then
            if not FileName.EndsWith('.' + IncomingDocAttachment."File Extension") then
                FileName += '.' + IncomingDocAttachment."File Extension";
        FileJson.Add('data', Base64Convert.ToBase64(InStream));
        FileJson.Add('mimeType', GuessMimeType(IncomingDocAttachment."File Extension"));
        FileJson.Add('fileName', FileName);
        exit(true);
    end;

    local procedure ResolveDocumentAttachment(AttachmentJson: JsonObject; var FileJson: JsonObject): Boolean
    var
        DocAttachment: Record "Document Attachment";
        TempBlob: Codeunit "Temp Blob";
        Base64Convert: Codeunit "Base64 Convert";
        InStream: InStream;
        SystemIdGuid: Guid;
        FileName: Text;
    begin
        if not Evaluate(SystemIdGuid, GetTextValue(AttachmentJson, 'systemId')) then
            exit(false);
        DocAttachment.SetLoadFields("File Name", "File Extension");
        if not DocAttachment.GetBySystemId(SystemIdGuid) then
            exit(false);
        DocAttachment.GetAsTempBlob(TempBlob);
        if not TempBlob.HasValue() then
            exit(false);
        TempBlob.CreateInStream(InStream);
        FileName := DocAttachment."File Name";
        if (FileName <> '') and (DocAttachment."File Extension" <> '') then
            if not FileName.EndsWith('.' + DocAttachment."File Extension") then
                FileName += '.' + DocAttachment."File Extension";
        FileJson.Add('data', Base64Convert.ToBase64(InStream));
        FileJson.Add('mimeType', GuessMimeType(DocAttachment."File Extension"));
        FileJson.Add('fileName', FileName);
        exit(true);
    end;

    local procedure GuessMimeType(FileExtension: Text): Text
    begin
        case LowerCase(DelChr(FileExtension, '<>', '.')) of
            'pdf':
                exit('application/pdf');
            'png':
                exit('image/png');
            'jpg', 'jpeg':
                exit('image/jpeg');
            'gif':
                exit('image/gif');
            'webp':
                exit('image/webp');
            'xml':
                exit('application/xml');
            'json':
                exit('application/json');
            'txt', 'csv':
                exit('text/plain');
            else
                exit('application/octet-stream');
        end;
    end;
}
