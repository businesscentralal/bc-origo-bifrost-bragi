namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

/// <summary>
/// Thin HTTP client shared by the OpenAI-compatible chat providers: posts a Chat
/// Completions-shaped request to an explicit endpoint and lists models from an
/// explicit endpoint, both with a caller-supplied auth header and API key.
/// Buffers the last call for debug-mode request logging via LogLastRequest.
/// </summary>
codeunit 10035411 "LangModel API Client ori"
{
    Access = Internal;

    var
        LastOperation: Text[50];
        LastHttpMethod: Text[10];
        LastRequestUrl: Text;
        LastRequestText: Text;
        LastResponseText: Text;
        LastErrorText: Text;
        LastHttpStatus: Integer;
        LastElapsed: Duration;
        LastIsSuccess: Boolean;
        HasPendingLog: Boolean;
        ServiceNameTok: Label 'LLM', Locked = true;
        BearerTok: Label 'Bearer %1', Locked = true;
        CallFailedErr: Label 'Could not reach the LLM API. %1', Comment = '%1 = error detail, is-IS=Náði ekki sambandi við LLM API. %1';
        ApiStatusErr: Label 'LLM API returned status %1. %2', Comment = '%1 = status code, %2 = detail, is-IS=LLM API skilaði stöðu %1. %2';
        InvalidResponseErr: Label 'Received an invalid response from the LLM API.', Comment = 'is-IS=Ógilt svar barst frá LLM API.';

    /// <summary>
    /// Writes the buffered log entry from the last API call to the shared request log.
    /// Only logs when Request Debug Mode is enabled.
    /// </summary>
    procedure LogLastRequest()
    var
        Setup: Record "Setup ori";
        Logger: Codeunit "Request Logger ori";
    begin
        if not HasPendingLog then
            exit;
        HasPendingLog := false;

        Setup.SetLoadFields("Request Debug Mode");
        if not Setup.Get() then
            exit;
        if not Setup."Request Debug Mode" then
            exit;

        Logger.Log(
            LastOperation, LastHttpMethod, LastRequestUrl, ServiceNameTok,
            LastHttpStatus, LastElapsed, LastIsSuccess, LastErrorText,
            LastRequestText, LastResponseText,
            Enum::"Request Log Type ori"::"LLM");
        Logger.Insert();
    end;

    /// <summary>
    /// Sends a chat completion to an explicit endpoint URL with the specified auth.
    /// </summary>
    [NonDebuggable]
    procedure SendToEndpoint(ChatUrl: Text; AuthHeaderName: Text; ApiKey: SecretText; TimeoutMs: Integer; RequestBody: JsonObject) Response: JsonObject
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
        HasPendingLog := false;
        RequestBody.WriteTo(RequestText);
        HttpContent.WriteFrom(RequestText);
        HttpContent.GetHeaders(ContentHeaders);
        if ContentHeaders.Contains('Content-Type') then
            ContentHeaders.Remove('Content-Type');
        ContentHeaders.Add('Content-Type', 'application/json');

        DefaultHeaders := HttpClientVar.DefaultRequestHeaders();
        if AuthHeaderName = 'Authorization' then
            DefaultHeaders.Add('Authorization', SecretStrSubstNo(BearerTok, ApiKey))
        else
            DefaultHeaders.Add(AuthHeaderName, ApiKey);
        HttpClientVar.Timeout(TimeoutMs);

        StartTime := CurrentDateTime();
        if not HttpClientVar.Post(ChatUrl, HttpContent, HttpResponse) then begin
            BufferLog('chat/completions', 'POST', ChatUrl, RequestText, '',
                GetLastErrorText(), 0, CurrentDateTime() - StartTime, false);
            Error(CallFailedErr, GetLastErrorText());
        end;

        HttpResponse.Content.ReadAs(ResponseText);

        if not HttpResponse.IsSuccessStatusCode() then begin
            BufferLog('chat/completions', 'POST', ChatUrl, RequestText, ResponseText,
                GetErrorDetail(ResponseText), HttpResponse.HttpStatusCode(), CurrentDateTime() - StartTime, false);
            Error(ApiStatusErr, Format(HttpResponse.HttpStatusCode()), GetErrorDetail(ResponseText));
        end;

        BufferLog('chat/completions', 'POST', ChatUrl, RequestText, ResponseText,
            '', HttpResponse.HttpStatusCode(), CurrentDateTime() - StartTime, true);

        if not Response.ReadFrom(ResponseText) then
            Error(InvalidResponseErr);
    end;

    /// <summary>
    /// Lists models from an explicit endpoint URL with the specified auth.
    /// </summary>
    [NonDebuggable]
    procedure ListModelsFromEndpoint(ModelsUrl: Text; AuthHeaderName: Text; ApiKey: SecretText) Models: JsonArray
    var
        HttpClientVar: HttpClient;
        HttpResponse: HttpResponseMessage;
        DefaultHeaders: HttpHeaders;
        Response: JsonObject;
        DataToken: JsonToken;
        ResponseText: Text;
    begin
        DefaultHeaders := HttpClientVar.DefaultRequestHeaders();
        if AuthHeaderName = 'Authorization' then
            DefaultHeaders.Add('Authorization', SecretStrSubstNo(BearerTok, ApiKey))
        else
            DefaultHeaders.Add(AuthHeaderName, ApiKey);

        if not HttpClientVar.Get(ModelsUrl, HttpResponse) then
            Error(CallFailedErr, GetLastErrorText());

        HttpResponse.Content.ReadAs(ResponseText);

        if not HttpResponse.IsSuccessStatusCode() then
            Error(ApiStatusErr, Format(HttpResponse.HttpStatusCode()), GetErrorDetail(ResponseText));

        if not Response.ReadFrom(ResponseText) then
            Error(InvalidResponseErr);

        if Response.Get('data', DataToken) then
            if DataToken.IsArray() then
                Models := DataToken.AsArray();
    end;

    /// <summary>
    /// Extracts the assistant text from an OpenAI-compatible chat completions response.
    /// </summary>
    procedure ExtractText(Response: JsonObject) ResultText: Text
    var
        ChoicesToken: JsonToken;
        FirstChoice: JsonToken;
        MessageToken: JsonToken;
        ContentToken: JsonToken;
    begin
        if not Response.Get('choices', ChoicesToken) then
            exit('');
        if not ChoicesToken.IsArray() then
            exit('');
        if ChoicesToken.AsArray().Count() = 0 then
            exit('');

        ChoicesToken.AsArray().Get(0, FirstChoice);
        if not FirstChoice.AsObject().Get('message', MessageToken) then
            exit('');
        if not MessageToken.AsObject().Get('content', ContentToken) then
            exit('');
        if ContentToken.IsValue() then
            if not ContentToken.AsValue().IsNull() then
                ResultText := ContentToken.AsValue().AsText();
    end;

    local procedure GetErrorDetail(ResponseText: Text): Text
    var
        ErrorObject: JsonObject;
        ErrorToken: JsonToken;
        MessageToken: JsonToken;
    begin
        if ErrorObject.ReadFrom(ResponseText) then
            if ErrorObject.Get('error', ErrorToken) then begin
                if ErrorToken.IsValue() then
                    exit(ErrorToken.AsValue().AsText());
                if ErrorToken.IsObject() then
                    if ErrorToken.AsObject().Get('message', MessageToken) then
                        if MessageToken.IsValue() then
                            exit(MessageToken.AsValue().AsText());
            end;
        exit(CopyStr(ResponseText, 1, 1000));
    end;

    local procedure BufferLog(Operation: Text[50]; HttpMethod: Text[10]; RequestUrl: Text; RequestText: Text; ResponseText: Text; ErrorText: Text; HttpStatus: Integer; Elapsed: Duration; IsSuccess: Boolean)
    begin
        LastOperation := Operation;
        LastHttpMethod := HttpMethod;
        LastRequestUrl := RequestUrl;
        LastRequestText := RequestText;
        LastResponseText := ResponseText;
        LastErrorText := ErrorText;
        LastHttpStatus := HttpStatus;
        LastElapsed := Elapsed;
        LastIsSuccess := IsSuccess;
        HasPendingLog := true;
    end;
}
