namespace Origo.Bifrost.Bragi;
using Origo.Bifrost;

using System.Text;
using System.Utilities;

/// <summary>
/// Executes a single Bifrost message type in its own Codeunit.Run scope so that
/// message types which commit or fail are isolated from the surrounding chat tool loop.
/// Binary responses (non-text content types) are base64-encoded for blob store consumption.
/// </summary>
codeunit 10035386 "MCP Tool Executor ori"
{
    Access = Internal;
    SingleInstance = true;

    trigger OnRun()
    var
        Dispatcher: Codeunit "Dispatcher ori";
        ResponseTempBlob: Codeunit "Temp Blob";
        Base64Convert: Codeunit "Base64 Convert";
        RequestContent: BigText;
        ResponseBigText: BigText;
        ResponseInStr: InStream;
        MessageVersion: Enum "Message Version ori";
    begin
        Clear(ResponseText);
        Clear(ResponseContentType);
        IsBinaryResponse := false;

        if RequestText <> '' then
            RequestContent.AddText(RequestText);

        Dispatcher.EnqueueAndProcess(MessageType, MessageVersion::"1.0", SubjectText, SourceText, 'application/json',
            RequestContent, EmptyTaskId, 0, EmptyMessageId, ResponseTempBlob, ResponseContentType, ResponseTime);

        if IsPassThroughContentType(ResponseContentType) then begin
            ResponseTempBlob.CreateInStream(ResponseInStr, TextEncoding::UTF8);
            ResponseBigText.Read(ResponseInStr);
            if ResponseBigText.Length() > 0 then
                ResponseBigText.GetSubText(ResponseText, 1);
        end else begin
            ResponseTempBlob.CreateInStream(ResponseInStr);
            ResponseText := Base64Convert.ToBase64(ResponseInStr);
            IsBinaryResponse := true;
        end;
    end;

    procedure SetParameters(NewMessageType: Enum "Message Type ori"; NewRequestText: Text)
    begin
        SetParameters(NewMessageType, '', NewRequestText);
    end;

    procedure SetParameters(NewMessageType: Enum "Message Type ori"; NewSubject: Text; NewRequestText: Text)
    begin
        MessageType := NewMessageType;
        SubjectText := CopyStr(NewSubject, 1, MaxStrLen(SubjectText));
        SourceText := 'Bifrost MCP Tool Server';
        RequestText := NewRequestText;
        Clear(ResponseText);
        Clear(ResponseContentType);
        IsBinaryResponse := false;
    end;

    procedure GetResponseText(): Text
    begin
        exit(ResponseText);
    end;

    procedure GetResponseContentType(): Text[50]
    begin
        exit(ResponseContentType);
    end;

    procedure GetIsBinaryResponse(): Boolean
    begin
        exit(IsBinaryResponse);
    end;

    local procedure IsPassThroughContentType(ContentType: Text[50]): Boolean
    begin
        if ContentType = '' then
            exit(true);
        if ContentType.StartsWith('text/') then
            exit(true);
        if ContentType in ['application/json', 'application/xml'] then
            exit(true);
        exit(false);
    end;

    var
        MessageType: Enum "Message Type ori";
        SubjectText: Text[250];
        SourceText: Text[250];
        RequestText: Text;
        ResponseText: Text;
        ResponseContentType: Text[50];
        ResponseTime: Duration;
        IsBinaryResponse: Boolean;
        EmptyTaskId: Guid;
        EmptyMessageId: Guid;
}
