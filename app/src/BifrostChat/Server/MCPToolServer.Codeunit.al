namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

using System.Text;
using System.Utilities;

/// <summary>
/// In-process MCP tool server that exposes Bifrost message types as tools
/// for any AI chat provider. Handles session bootstrap, tool listing, tool
/// execution, and blob storage for large binary responses.
/// </summary>
codeunit 10035387 "MCP Tool Server ori"
{
    Access = Public;
    SingleInstance = true;

    var
        ToolExecutor: Codeunit "MCP Tool Executor ori";
        BlobStore: Dictionary of [Text, Text];
        BlobContentTypes: Dictionary of [Text, Text];
        BlobSizes: Dictionary of [Text, Integer];
        ToolRegistry: JsonArray;
        ToolsBuilt: Boolean;
        CachedSystemPrompt: Text;
        MaxBlobStoreSizeChars: Integer;
        MinBlobifyChars: Integer;
        BlobRefPatternTok: Label '{{blob:', Locked = true;
        UnknownToolErr: Label 'Unknown tool: %1', Comment = '%1 = tool name, is-IS=Óþekkt verkfæri: %1';
        UnknownMessageTypeErr: Label 'Unknown message type: %1', Comment = '%1 = message type name, is-IS=Óþekkt skilaboðategund: %1';
        InvalidBlobRefErr: Label 'Invalid or expired blob reference: %1', Comment = '%1 = blob GUID, is-IS=Ógild eða útrunnin blobvísun: %1';
        DownloadNoGuiErr: Label 'download_blob requires an interactive BC session.', Locked = true;

    /// <summary>
    /// Builds the system prompt that starts a chat session. Clears any previous session state,
    /// then reads the caller's identity, language, administrator prompt and the user and company
    /// memory through the matching Bifrost message types and adds the tool usage rules. The
    /// result is cached, so later calls in the same session return the same text without
    /// re-reading anything. Call ClearSession to force a rebuild.
    /// </summary>
    /// <param name="RecordContext">Description of the record the user currently has open, added to the prompt when not empty.</param>
    /// <returns>Text. The complete system prompt for the chat provider.</returns>
    procedure Bootstrap(RecordContext: Text) SystemPrompt: Text
    var
        PromptBuilder: TextBuilder;
        WhoAmIResult: Text;
        MemoryUserResult: Text;
        MemoryCompanyResult: Text;
        AdminPrompt: Text;
        LanguageName: Text;
        IsError: Boolean;
    begin
        if CachedSystemPrompt <> '' then begin
            SystemPrompt := CachedSystemPrompt;
            exit;
        end;

        ClearSession();

        DispatchMessageType(Enum::"Message Type ori"::"Help.WhoAmI.Get", '', '', WhoAmIResult, IsError);
        LanguageName := ExtractLanguageName(WhoAmIResult);
        AdminPrompt := ExtractJsonProperty(WhoAmIResult, 'systemPrompt');

        DispatchMessageType(Enum::"Message Type ori"::"Memory.User.List", '', '', MemoryUserResult, IsError);
        DispatchMessageType(Enum::"Message Type ori"::"Memory.Company.List", '', '', MemoryCompanyResult, IsError);

        PromptBuilder.AppendLine('You are a Business Central assistant with Bifrost tools for live data and actions.');
        PromptBuilder.AppendLine('');
        PromptBuilder.AppendLine('RULES:');
        PromptBuilder.AppendLine('1. Use tools for live BC data. Read before write. Confirm before writes.');
        PromptBuilder.AppendLine('2. Be concise and business-facing. Explain failures in plain language.');
        PromptBuilder.AppendLine('3. Never mention secrets or internal config.');
        PromptBuilder.AppendLine('4. Use format:"csv" on data tools for compact pipe-delimited output.');
        PromptBuilder.AppendLine('5. Use list_message_types and get_message_type_help to discover available operations.');
        PromptBuilder.AppendLine('6. For a full getting-started guide, call get_message_type_help with messageType "Help.Bifrost.Get" — it covers discovery, data access, syntax, and playbook patterns.');
        PromptBuilder.AppendLine('');
        PromptBuilder.AppendLine('BLOBS: Binary results and large base64 fields (media, images) auto-convert to {{blob:<guid>}} refs.');
        PromptBuilder.AppendLine('Pass refs to other tools or back to set_records — refs in arguments are auto-resolved at any depth.');
        PromptBuilder.AppendLine('Use download_blob to save files. Use get_blob to peek at content.');
        PromptBuilder.AppendLine('');
        PromptBuilder.AppendLine('SYNTAX:');
        PromptBuilder.AppendLine('- tableView: CONST for single value, FILTER for multi/ranges/wildcards. Never put pipes in CONST.');
        PromptBuilder.AppendLine('- Option/Enum fields in tableView: always use integer ordinals, e.g. Document Type=CONST(1) for Order.');
        PromptBuilder.AppendLine('- primaryKey objects use jsonKey (no spaces/dots: DocumentType, No_). tableView WHERE uses display names (Document Type, No.).');
        PromptBuilder.AppendLine('');

        PromptBuilder.AppendLine('IDENTITY:');
        PromptBuilder.AppendLine(WhoAmIResult);
        PromptBuilder.AppendLine('');

        if LanguageName <> '' then begin
            PromptBuilder.AppendLine('LANGUAGE: Reply in ' + LanguageName + '.');
            PromptBuilder.AppendLine('');
        end;

        if AdminPrompt <> '' then begin
            PromptBuilder.AppendLine(AdminPrompt);
            PromptBuilder.AppendLine('');
        end;

        PromptBuilder.AppendLine('MEMORY:');
        PromptBuilder.AppendLine(MemoryUserResult);
        PromptBuilder.AppendLine(MemoryCompanyResult);

        if RecordContext <> '' then begin
            PromptBuilder.AppendLine('');
            PromptBuilder.AppendLine('RECORD CONTEXT:');
            PromptBuilder.AppendLine(RecordContext);
            PromptBuilder.AppendLine('When the user refers to the current page record, use its tableId and recordSystemId with get_records to fetch data.');
        end;

        SystemPrompt := PromptBuilder.ToText();
        CachedSystemPrompt := SystemPrompt;
    end;

    /// <summary>
    /// Returns the tool definitions to send to the chat provider, building the registry on the
    /// first call and reusing it afterwards.
    /// </summary>
    /// <param name="Tools">Receives the tool definitions as a JSON array.</param>
    procedure ListTools(var Tools: JsonArray)
    begin
        if not ToolsBuilt then
            BuildToolRegistry();
        Tools := ToolRegistry;
    end;

    /// <summary>
    /// Runs one tool call on behalf of the chat provider. Blob references in the arguments are
    /// resolved first, the tool is dispatched to its Bifrost message type, large base64 values in
    /// the response are replaced by blob references, and the call is written to the request log.
    /// An unknown tool name is reported through IsError instead of raising an error.
    /// </summary>
    /// <param name="ToolName">Name of the tool to run, as published by ListTools.</param>
    /// <param name="Arguments">Tool arguments as sent by the chat provider.</param>
    /// <param name="ResultText">Receives the tool result, or the error message when IsError is true.</param>
    /// <param name="IsError">Receives true when the tool failed or the tool name is unknown.</param>
    /// <returns>Boolean. Always true - the call was handled. Read IsError for the outcome.</returns>
    procedure CallTool(ToolName: Text; Arguments: JsonObject; var ResultText: Text; var IsError: Boolean): Boolean
    var
        StartTime: DateTime;
    begin
        StartTime := CurrentDateTime();
        IsError := false;

        // Resolve blob references in all argument string values (skip blob-management tools)
        if not (ToolName in ['get_blob', 'delete_blobs', 'download_blob']) then
            ResolveArgumentBlobs(Arguments);

        case ToolName of
            'invoke_message_type':
                HandleInvokeMessageType(Arguments, ResultText, IsError);
            'list_message_types':
                HandleListMessageTypes(Arguments, ResultText, IsError);
            'get_message_type_help':
                DispatchMessageType(Enum::"Message Type ori"::"Help.Implementation.Get",
                    GetTextArg(Arguments, 'messageType'), '', ResultText, IsError);
            'who_am_i':
                DispatchMessageType(Enum::"Message Type ori"::"Help.WhoAmI.Get", '', '', ResultText, IsError);
            'get_records':
                HandleDataTool(Enum::"Message Type ori"::"Data.Records.Get", Arguments, ResultText, IsError);
            'set_records':
                HandleDataTool(Enum::"Message Type ori"::"Data.Records.Set", Arguments, ResultText, IsError);
            'get_record_ids':
                HandleDataTool(Enum::"Message Type ori"::"Data.RecordIds.Get", Arguments, ResultText, IsError);
            'get_blob':
                HandleGetBlob(Arguments, ResultText, IsError);
            'set_blob':
                HandleSetBlob(Arguments, ResultText);
            'list_blobs':
                HandleListBlobs(ResultText);
            'delete_blobs':
                HandleDeleteBlobs(Arguments, ResultText);
            'download_blob':
                HandleDownloadBlob(Arguments, ResultText, IsError);
            'get_user_memory':
                HandleDataTool(Enum::"Message Type ori"::"Memory.User.Get", Arguments, ResultText, IsError);
            'set_user_memory':
                HandleDataTool(Enum::"Message Type ori"::"Memory.User.Set", Arguments, ResultText, IsError);
            'get_company_memory':
                HandleDataTool(Enum::"Message Type ori"::"Memory.Company.Get", Arguments, ResultText, IsError);
            'set_company_memory':
                HandleDataTool(Enum::"Message Type ori"::"Memory.Company.Set", Arguments, ResultText, IsError);
            'get_page_url':
                HandleDataTool(Enum::"Message Type ori"::"Help.PageUrl.Get", Arguments, ResultText, IsError);
            'get_record_count':
                HandleGetRecordCount(Arguments, ResultText, IsError);
            'get_totals':
                HandleDataTool(Enum::"Message Type ori"::"Data.Totals.Get", Arguments, ResultText, IsError);
            'find_entries':
                HandleDataTool(Enum::"Message Type ori"::"Data.Entries.Find", Arguments, ResultText, IsError);
            'get_fields':
                HandleSubjectDataTool(Enum::"Message Type ori"::"Help.Fields.Get", Arguments, ResultText, IsError);
            'search_tables':
                HandleSubjectDataTool(Enum::"Message Type ori"::"Help.Tables.Get", Arguments, ResultText, IsError);
            'get_next_line_no':
                HandleSubjectDataTool(Enum::"Message Type ori"::"Help.NextLineNo.Get", Arguments, ResultText, IsError);
            else begin
                ResultText := StrSubstNo(UnknownToolErr, ToolName);
                IsError := true;
            end;
        end;

        // Replace inline base64 content with blob refs
        if not IsError then
            BlobifyResponseValues(ResultText);

        LogToolCall(ToolName, Arguments, ResultText, IsError, CurrentDateTime() - StartTime);

        exit(true);
    end;

    /// <summary>
    /// Returns how many tools the server publishes, building the registry first when needed.
    /// Used by the setup page to show that the tool server is available.
    /// </summary>
    /// <returns>Integer. Number of tool definitions in the registry.</returns>
    procedure GetToolCount(): Integer
    begin
        if not ToolsBuilt then
            BuildToolRegistry();
        exit(ToolRegistry.Count());
    end;

    /// <summary>
    /// Drops the session state this single-instance codeunit holds: the stored blobs with their
    /// content types and sizes, and the cached system prompt. Call it when a new chat session
    /// starts so the next Bootstrap builds a fresh prompt.
    /// </summary>
    procedure ClearSession()
    begin
        Clear(BlobStore);
        Clear(BlobContentTypes);
        Clear(BlobSizes);
        Clear(CachedSystemPrompt);
    end;

    local procedure LogToolCall(ToolName: Text; Arguments: JsonObject; ResultText: Text; IsError: Boolean; Elapsed: Duration)
    var
        Setup: Record "Setup ori";
        Logger: Codeunit "Request Logger ori";
        ArgsText: Text;
    begin
        Setup.SetLoadFields("Request Debug Mode");
        if not Setup.Get() then
            exit;
        if not Setup."Request Debug Mode" then
            exit;

        Arguments.WriteTo(ArgsText);
        Logger.Log(
            CopyStr(ToolName, 1, 50),
            'TOOL',
            '',
            'MCP Tool Server',
            0,
            Elapsed,
            not IsError,
            '',
            ArgsText,
            ResultText,
            Enum::"Request Log Type ori"::"MCP Tool");
        Logger.Insert();
    end;

    /// <summary>
    /// Builds tool definitions for a specific set of Bifrost message type names.
    /// Reusable by any LLM provider that wants to expose a subset of message types as tools.
    /// </summary>
    procedure BuildDynamicToolDefs(MessageTypeNames: JsonArray; var Tools: JsonArray; var ToolNameMap: Dictionary of [Text, Integer])
    var
        NameToken: JsonToken;
        MessageType: Enum "Message Type ori";
        MemberName: Text;
        SanitizedName: Text;
    begin
        Clear(Tools);
        Clear(ToolNameMap);
        foreach NameToken in MessageTypeNames do begin
            if not NameToken.IsValue() then
                continue;
            MemberName := NameToken.AsValue().AsText();
            if MemberName = '' then
                continue;
            if not Evaluate(MessageType, MemberName) then
                continue;

            SanitizedName := SanitizeToolName(MemberName);
            if ToolNameMap.ContainsKey(SanitizedName) then
                continue;

            ToolNameMap.Add(SanitizedName, MessageType.AsInteger());
            Tools.Add(BuildDynamicToolDef(SanitizedName, MemberName));
        end;
    end;

    /// <summary>
    /// Sanitizes a Bifrost message type name into a tool-API-safe identifier.
    /// Replaces non-alphanumeric characters (except _ and -) with underscore.
    /// </summary>
    procedure SanitizeToolName(MemberName: Text) Result: Text
    var
        Index: Integer;
        Character: Char;
    begin
        for Index := 1 to StrLen(MemberName) do begin
            Character := MemberName[Index];
            if Character in ['A' .. 'Z', 'a' .. 'z', '0' .. '9', '_', '-'] then
                Result += Character
            else
                Result += '_';
        end;
        if StrLen(Result) > 64 then
            Result := CopyStr(Result, 1, 64);
    end;

    local procedure BuildDynamicToolDef(ToolName: Text; MemberName: Text) ToolObject: JsonObject
    var
        InputSchema: JsonObject;
        Properties: JsonObject;
        RequestProperty: JsonObject;
        SubjectProperty: JsonObject;
        DescLbl: Label 'Executes the %1 message type. Provide its JSON request payload in "request" (omit if no input needed).', Locked = true;
    begin
        RequestProperty.Add('type', 'string');
        RequestProperty.Add('description', 'JSON request payload for the message type.');
        Properties.Add('request', RequestProperty);

        SubjectProperty.Add('type', 'string');
        SubjectProperty.Add('description', 'Optional subject (record key, GUID, document number).');
        Properties.Add('subject', SubjectProperty);

        InputSchema.Add('type', 'object');
        InputSchema.Add('properties', Properties);

        ToolObject.Add('name', ToolName);
        ToolObject.Add('description', StrSubstNo(DescLbl, MemberName));
        ToolObject.Add('inputSchema', InputSchema);
    end;

    // -- Tool Handlers --

    local procedure HandleInvokeMessageType(Arguments: JsonObject; var ResultText: Text; var IsError: Boolean)
    var
        MessageType: Enum "Message Type ori";
        MsgTypeName: Text;
        Subject: Text;
        RequestData: Text;
        Format: Text;
    begin
        MsgTypeName := GetTextArg(Arguments, 'type');
        Subject := GetTextArg(Arguments, 'subject');
        RequestData := GetTextArg(Arguments, 'data');
        Format := GetTextArg(Arguments, 'format');

        if not TryEvaluateMessageType(MsgTypeName, MessageType) then begin
            ResultText := StrSubstNo(UnknownMessageTypeErr, MsgTypeName);
            IsError := true;
            exit;
        end;

        DispatchMessageType(MessageType, Subject, RequestData, ResultText, IsError);
        if (not IsError) and (Format in ['table', 'csv']) then
            ResultText := JsonToTable(ResultText);
    end;

    local procedure HandleDataTool(MessageType: Enum "Message Type ori"; Arguments: JsonObject; var ResultText: Text; var IsError: Boolean)
    var
        CleanArgs: JsonObject;
        DataText: Text;
        Format: Text;
        JsonKey: Text;
        Token: JsonToken;
    begin
        Format := GetTextArg(Arguments, 'format');
        // Strip tool-level params before passing to message type
        foreach JsonKey in Arguments.Keys() do
            if not (JsonKey in ['format']) then begin
                Arguments.Get(JsonKey, Token);
                CleanArgs.Add(JsonKey, Token);
            end;
        CleanArgs.WriteTo(DataText);
        DispatchMessageType(MessageType, '', DataText, ResultText, IsError);
        if (not IsError) and (Format in ['table', 'csv']) then
            ResultText := JsonToTable(ResultText);
    end;

    local procedure DispatchMessageType(MessageType: Enum "Message Type ori"; Subject: Text; RequestData: Text; var ResultText: Text; var IsError: Boolean)
    begin
        ToolExecutor.SetParameters(MessageType, Subject, RequestData);
        if not ToolExecutor.Run() then begin
            ResultText := GetLastErrorText();
            IsError := true;
            exit;
        end;

        ResultText := ToolExecutor.GetResponseText();

        // Binary responses get stored as blobs automatically
        if ToolExecutor.GetIsBinaryResponse() then
            ResultText := StoreBlobAndReturnRef(ResultText, ToolExecutor.GetResponseContentType());
    end;

    [TryFunction]
    local procedure TryEvaluateMessageType(MsgTypeName: Text; var MessageType: Enum "Message Type ori")
    begin
        Evaluate(MessageType, MsgTypeName);
    end;

    // -- Blob Store --

    local procedure StoreBlobAndReturnRef(Base64Value: Text; ContentType: Text[50]) ResultJson: Text
    var
        BlobId: Text;
        ResultObject: JsonObject;
    begin
        EnforceBlobMemoryCap();
        BlobId := Format(CreateGuid(), 0, 4);
        BlobStore.Add(BlobId, Base64Value);
        BlobContentTypes.Add(BlobId, ContentType);
        BlobSizes.Add(BlobId, StrLen(Base64Value));

        ResultObject.Add('blobRef', '{{blob:' + BlobId + '}}');
        ResultObject.Add('size', StrLen(Base64Value));
        ResultObject.Add('contentType', ContentType);
        ResultObject.WriteTo(ResultJson);
    end;

    local procedure HandleGetBlob(Arguments: JsonObject; var ResultText: Text; var IsError: Boolean)
    var
        BlobRef: Text;
        BlobId: Text;
        MaxChars: Integer;
        BlobContent: Text;
    begin
        BlobRef := GetTextArg(Arguments, 'ref');
        BlobId := ExtractBlobId(BlobRef);
        if not BlobStore.ContainsKey(BlobId) then begin
            ResultText := StrSubstNo(InvalidBlobRefErr, BlobRef);
            IsError := true;
            exit;
        end;

        MaxChars := GetIntArg(Arguments, 'maxChars', 20000);
        BlobContent := BlobStore.Get(BlobId);

        if StrLen(BlobContent) > MaxChars then
            ResultText := CopyStr(BlobContent, 1, MaxChars) + '... [truncated, total ' + Format(StrLen(BlobContent)) + ' chars]'
        else
            ResultText := BlobContent;
    end;

    local procedure HandleDownloadBlob(Arguments: JsonObject; var ResultText: Text; var IsError: Boolean)
    var
        Base64Convert: Codeunit "Base64 Convert";
        TempBlob: Codeunit "Temp Blob";
        BlobRef: Text;
        BlobId: Text;
        FileName: Text;
        ContentType: Text;
        BlobContent: Text;
        OutStr: OutStream;
        InStr: InStream;
        ResultObject: JsonObject;
    begin
        if not GuiAllowed() then begin
            ResultText := DownloadNoGuiErr;
            IsError := true;
            exit;
        end;

        BlobRef := GetTextArg(Arguments, 'ref');
        BlobId := ExtractBlobId(BlobRef);
        if not BlobStore.ContainsKey(BlobId) then begin
            ResultText := StrSubstNo(InvalidBlobRefErr, BlobRef);
            IsError := true;
            exit;
        end;

        FileName := GetTextArg(Arguments, 'filename');
        if FileName = '' then
            FileName := 'download';

        BlobContent := BlobStore.Get(BlobId);
        if BlobContentTypes.ContainsKey(BlobId) then
            ContentType := BlobContentTypes.Get(BlobId);

        TempBlob.CreateOutStream(OutStr);
        if ContentType.StartsWith('text/') or (ContentType in ['application/json', 'application/xml', '']) then
            OutStr.WriteText(BlobContent)
        else
            Base64Convert.FromBase64(BlobContent, OutStr);
        TempBlob.CreateInStream(InStr);
        DownloadFromStream(InStr, '', '', '', FileName);

        ResultObject.Add('status', 'Success');
        ResultObject.Add('filename', FileName);
        ResultObject.Add('size', BlobSizes.Get(BlobId));
        ResultObject.WriteTo(ResultText);
    end;

    local procedure HandleSetBlob(Arguments: JsonObject; var ResultText: Text)
    var
        Content: Text;
        ContentType: Text;
    begin
        Content := GetTextArg(Arguments, 'content');
        ContentType := GetTextArg(Arguments, 'contentType');
        if ContentType = '' then
            ContentType := 'text/plain';

        ResultText := StoreBlobAndReturnRef(Content, CopyStr(ContentType, 1, 50));
    end;

    local procedure HandleListBlobs(var ResultText: Text)
    var
        ResultObject: JsonObject;
        BlobArray: JsonArray;
        BlobEntry: JsonObject;
        BlobId: Text;
        TotalSize: Integer;
    begin
        foreach BlobId in BlobStore.Keys() do begin
            Clear(BlobEntry);
            BlobEntry.Add('ref', '{{blob:' + BlobId + '}}');
            BlobEntry.Add('size', BlobSizes.Get(BlobId));
            BlobEntry.Add('contentType', BlobContentTypes.Get(BlobId));
            BlobArray.Add(BlobEntry);
            TotalSize += BlobSizes.Get(BlobId);
        end;

        ResultObject.Add('blobs', BlobArray);
        ResultObject.Add('totalSize', TotalSize);
        ResultObject.WriteTo(ResultText);
    end;

    local procedure HandleDeleteBlobs(Arguments: JsonObject; var ResultText: Text)
    var
        RefsToken: JsonToken;
        RefsArray: JsonArray;
        RefToken: JsonToken;
        ResultObject: JsonObject;
        BlobId: Text;
        RefText: Text;
        Deleted: Integer;
        TotalSize: Integer;
    begin
        if Arguments.Get('refs', RefsToken) then
            if RefsToken.IsArray() then
                RefsArray := RefsToken.AsArray();

        foreach RefToken in RefsArray do begin
            RefText := RefToken.AsValue().AsText();
            if RefText = '*' then begin
                Deleted := BlobStore.Count();
                Clear(BlobStore);
                Clear(BlobContentTypes);
                Clear(BlobSizes);
                TotalSize := 0;
            end else begin
                BlobId := ExtractBlobId(RefText);
                if BlobStore.ContainsKey(BlobId) then begin
                    BlobStore.Remove(BlobId);
                    BlobContentTypes.Remove(BlobId);
                    BlobSizes.Remove(BlobId);
                    Deleted += 1;
                end;
            end;
        end;

        foreach BlobId in BlobSizes.Keys() do
            TotalSize += BlobSizes.Get(BlobId);

        ResultObject.Add('deleted', Deleted);
        ResultObject.Add('remainingSize', TotalSize);
        ResultObject.WriteTo(ResultText);
    end;

    local procedure ExtractBlobId(BlobRef: Text): Text
    begin
        // {{blob:guid}} → guid
        if BlobRef.StartsWith('{{blob:') then
            exit(CopyStr(BlobRef, 8, StrLen(BlobRef) - 9));
        exit(BlobRef);
    end;

    local procedure EnforceBlobMemoryCap()
    var
        BlobId: Text;
        TotalSize: Integer;
        OldestKey: Text;
    begin
        if MaxBlobStoreSizeChars = 0 then
            MaxBlobStoreSizeChars := 50000000; // ~50MB in chars

        foreach BlobId in BlobSizes.Keys() do
            TotalSize += BlobSizes.Get(BlobId);

        while (TotalSize > MaxBlobStoreSizeChars) and (BlobStore.Count() > 0) do begin
            OldestKey := BlobStore.Keys().Get(1);
            TotalSize -= BlobSizes.Get(OldestKey);
            BlobStore.Remove(OldestKey);
            BlobContentTypes.Remove(OldestKey);
            BlobSizes.Remove(OldestKey);
        end;
    end;

    local procedure ResolveArgumentBlobs(var Arguments: JsonObject)
    begin
        ResolveJsonObjectBlobs(Arguments);
    end;

    local procedure ResolveJsonObjectBlobs(var JObject: JsonObject)
    var
        Keys: List of [Text];
        KeyName: Text;
        Token: JsonToken;
        ValueText: Text;
        ChildObject: JsonObject;
        ChildArray: JsonArray;
    begin
        Keys := JObject.Keys();
        foreach KeyName in Keys do begin
            JObject.Get(KeyName, Token);
            if Token.IsValue() then begin
                ValueText := Token.AsValue().AsText();
                if ValueText.Contains(BlobRefPatternTok) then begin
                    ResolveBlobsInText(ValueText);
                    JObject.Replace(KeyName, ValueText);
                end;
            end;
            if Token.IsObject() then begin
                ChildObject := Token.AsObject();
                ResolveJsonObjectBlobs(ChildObject);
                JObject.Replace(KeyName, ChildObject);
            end;
            if Token.IsArray() then begin
                ChildArray := Token.AsArray();
                ResolveJsonArrayBlobs(ChildArray);
                JObject.Replace(KeyName, ChildArray);
            end;
        end;
    end;

    local procedure ResolveJsonArrayBlobs(var JArray: JsonArray)
    var
        Index: Integer;
        Token: JsonToken;
        ValueText: Text;
        ChildObject: JsonObject;
        ChildArray: JsonArray;
    begin
        for Index := 0 to JArray.Count() - 1 do begin
            JArray.Get(Index, Token);
            if Token.IsValue() then begin
                ValueText := Token.AsValue().AsText();
                if ValueText.Contains(BlobRefPatternTok) then begin
                    ResolveBlobsInText(ValueText);
                    JArray.Set(Index, ValueText);
                end;
            end;
            if Token.IsObject() then begin
                ChildObject := Token.AsObject();
                ResolveJsonObjectBlobs(ChildObject);
                JArray.Set(Index, ChildObject);
            end;
            if Token.IsArray() then begin
                ChildArray := Token.AsArray();
                ResolveJsonArrayBlobs(ChildArray);
                JArray.Set(Index, ChildArray);
            end;
        end;
    end;

    local procedure ResolveBlobsInText(var InputText: Text)
    var
        StartPos: Integer;
        EndPos: Integer;
        BlobRef: Text;
        BlobId: Text;
        BlobContent: Text;
        SearchFrom: Integer;
    begin
        SearchFrom := 1;
        StartPos := StrPos(InputText, '{{blob:');
        while StartPos > 0 do begin
            EndPos := StrPos(CopyStr(InputText, StartPos), '}}');
            if EndPos = 0 then
                exit;
            EndPos := StartPos + EndPos + 1; // position after }}
            BlobRef := CopyStr(InputText, StartPos, EndPos - StartPos);
            BlobId := ExtractBlobId(BlobRef);
            if BlobStore.ContainsKey(BlobId) then begin
                BlobContent := BlobStore.Get(BlobId);
                InputText := CopyStr(InputText, 1, StartPos - 1) + BlobContent + CopyStr(InputText, EndPos);
                SearchFrom := StartPos + StrLen(BlobContent);
            end else
                SearchFrom := EndPos;
            if SearchFrom > StrLen(InputText) then
                exit;
            StartPos := StrPos(CopyStr(InputText, SearchFrom), '{{blob:');
            if StartPos > 0 then
                StartPos := StartPos + SearchFrom - 1;
        end;
    end;

    local procedure BlobifyResponseValues(var ResultText: Text)
    var
        RootObject: JsonObject;
        Changed: Boolean;
    begin
        if MinBlobifyChars = 0 then
            MinBlobifyChars := 2049;

        if not RootObject.ReadFrom(ResultText) then
            exit;

        BlobifyJsonObject(RootObject, Changed);
        if Changed then
            RootObject.WriteTo(ResultText);
    end;

    local procedure BlobifyJsonObject(var JObject: JsonObject; var Changed: Boolean)
    var
        Keys: List of [Text];
        KeyName: Text;
        Token: JsonToken;
        ValueText: Text;
        BlobRefJson: Text;
        ChildObject: JsonObject;
        ChildArray: JsonArray;
        ChildChanged: Boolean;
    begin
        Keys := JObject.Keys();
        foreach KeyName in Keys do begin
            JObject.Get(KeyName, Token);
            if Token.IsValue() then
                if not Token.AsValue().IsNull then begin
                    ValueText := Token.AsValue().AsText();
                    if (StrLen(ValueText) > MinBlobifyChars) and LooksLikeBase64(ValueText) then begin
                        BlobRefJson := StoreBlobAndReturnRef(ValueText, 'application/octet-stream');
                        JObject.Replace(KeyName, ExtractJsonProperty(BlobRefJson, 'blobRef'));
                        Changed := true;
                    end;
                end;
            if Token.IsObject() then begin
                ChildObject := Token.AsObject();
                ChildChanged := false;
                BlobifyJsonObject(ChildObject, ChildChanged);
                if ChildChanged then begin
                    JObject.Replace(KeyName, ChildObject);
                    Changed := true;
                end;
            end;
            if Token.IsArray() then begin
                ChildArray := Token.AsArray();
                ChildChanged := false;
                BlobifyJsonArray(ChildArray, ChildChanged);
                if ChildChanged then begin
                    JObject.Replace(KeyName, ChildArray);
                    Changed := true;
                end;
            end;
        end;
    end;

    local procedure BlobifyJsonArray(var JArray: JsonArray; var Changed: Boolean)
    var
        Index: Integer;
        Token: JsonToken;
        ValueText: Text;
        BlobRefJson: Text;
        ChildObject: JsonObject;
        ChildArray: JsonArray;
        ChildChanged: Boolean;
    begin
        for Index := 0 to JArray.Count() - 1 do begin
            JArray.Get(Index, Token);
            if Token.IsValue() then
                if not Token.AsValue().IsNull then begin
                    Token.WriteTo(ValueText);
                    if (StrLen(ValueText) > MinBlobifyChars) then begin
                        ValueText := Token.AsValue().AsText();
                        if LooksLikeBase64(ValueText) then begin
                            BlobRefJson := StoreBlobAndReturnRef(ValueText, 'application/octet-stream');
                            JArray.Set(Index, ExtractJsonProperty(BlobRefJson, 'blobRef'));
                            Changed := true;
                        end;
                    end;
                end;
            if Token.IsObject() then begin
                ChildObject := Token.AsObject();
                ChildChanged := false;
                BlobifyJsonObject(ChildObject, ChildChanged);
                if ChildChanged then begin
                    JArray.Set(Index, ChildObject);
                    Changed := true;
                end;
            end;
            if Token.IsArray() then begin
                ChildArray := Token.AsArray();
                ChildChanged := false;
                BlobifyJsonArray(ChildArray, ChildChanged);
                if ChildChanged then begin
                    JArray.Set(Index, ChildArray);
                    Changed := true;
                end;
            end;
        end;
    end;

    local procedure LooksLikeBase64(InputText: Text): Boolean
    var
        SampleLen: Integer;
        Index: Integer;
        Character: Char;
    begin
        if (StrLen(InputText) mod 4) <> 0 then
            exit(false);
        SampleLen := 64;
        if StrLen(InputText) < SampleLen then
            SampleLen := StrLen(InputText);
        for Index := 1 to SampleLen do begin
            Character := InputText[Index];
            if not (Character in ['A' .. 'Z', 'a' .. 'z', '0' .. '9', '+', '/', '=']) then
                exit(false);
        end;
        exit(true);
    end;

    local procedure HandleGetRecordCount(Arguments: JsonObject; var ResultText: Text; var IsError: Boolean)
    var
        CountArgs: JsonObject;
        FieldNumbers: JsonArray;
        ResultObject: JsonObject;
        CountToken: JsonToken;
        TableView: Text;
    begin
        CountArgs.Add('tableName', GetTextArg(Arguments, 'tableName'));
        TableView := GetTextArg(Arguments, 'tableView');
        if TableView <> '' then
            CountArgs.Add('tableView', TableView);
        FieldNumbers.Add(1);
        CountArgs.Add('fieldNumbers', FieldNumbers);
        CountArgs.Add('skip', 0);
        CountArgs.Add('take', 1);
        HandleDataTool(Enum::"Message Type ori"::"Data.Records.Get", CountArgs, ResultText, IsError);
        if IsError then
            exit;
        if ResultObject.ReadFrom(ResultText) then
            if ResultObject.Get('noOfRecords', CountToken) then begin
                Clear(ResultObject);
                ResultObject.Add('count', CountToken);
                ResultObject.WriteTo(ResultText);
            end;
    end;

    local procedure HandleSubjectDataTool(MessageType: Enum "Message Type ori"; Arguments: JsonObject; var ResultText: Text; var IsError: Boolean)
    var
        Subject: Text;
        Format: Text;
        DataText: Text;
        CleanArgs: JsonObject;
        JsonKey: Text;
        Token: JsonToken;
    begin
        Subject := GetTextArg(Arguments, 'tableName');
        Format := GetTextArg(Arguments, 'format');
        foreach JsonKey in Arguments.Keys() do
            if not (JsonKey in ['tableName', 'format']) then begin
                Arguments.Get(JsonKey, Token);
                CleanArgs.Add(JsonKey, Token);
            end;
        CleanArgs.WriteTo(DataText);
        if DataText = '{}' then
            DataText := '';
        DispatchMessageType(MessageType, Subject, DataText, ResultText, IsError);
        if (not IsError) and (Format in ['table', 'csv']) then
            ResultText := JsonToTable(ResultText);
    end;

    // -- JSON to table format --

    local procedure JsonToTable(JsonText: Text) Result: Text
    var
        RootObject: JsonObject;
        RecordsToken: JsonToken;
        RecordsArray: JsonArray;
        RecordToken: JsonToken;
        RecordObject: JsonObject;
        KeyName: Text;
        ValueToken: JsonToken;
        HeaderBuilder: TextBuilder;
        RowBuilder: TextBuilder;
        ResultBuilder: TextBuilder;
        RootKey: Text;
        RootValue: JsonToken;
        Headers: List of [Text];
        FirstRecord: Boolean;
    begin
        if not RootObject.ReadFrom(JsonText) then
            exit(JsonText);

        // Output non-array root properties as key: value lines
        foreach RootKey in RootObject.Keys() do begin
            RootObject.Get(RootKey, RootValue);
            if not RootValue.IsArray() then begin
                RootValue.WriteTo(Result);
                ResultBuilder.AppendLine(RootKey + ': ' + Result.TrimStart('"').TrimEnd('"'));
            end;
        end;

        // Find the first array property (typically "records")
        foreach RootKey in RootObject.Keys() do begin
            RootObject.Get(RootKey, RecordsToken);
            if RecordsToken.IsArray() then begin
                RecordsArray := RecordsToken.AsArray();
                break;
            end;
        end;
        if RecordsArray.Count() = 0 then
            exit(ResultBuilder.ToText());

        // Extract headers from first record
        RecordsArray.Get(0, RecordToken);
        RecordObject := RecordToken.AsObject();
        FirstRecord := true;
        foreach KeyName in RecordObject.Keys() do begin
            Headers.Add(KeyName);
            if not FirstRecord then
                HeaderBuilder.Append('|');
            HeaderBuilder.Append(KeyName);
            FirstRecord := false;
        end;
        ResultBuilder.AppendLine(HeaderBuilder.ToText());

        // Build rows
        foreach RecordToken in RecordsArray do begin
            if not RecordToken.IsObject() then
                continue;
            RecordObject := RecordToken.AsObject();
            Clear(RowBuilder);
            FirstRecord := true;
            foreach KeyName in Headers do begin
                if not FirstRecord then
                    RowBuilder.Append('|');
                if RecordObject.Get(KeyName, ValueToken) then
                    RowBuilder.Append(FormatTokenValue(ValueToken))
                else
                    RowBuilder.Append('');
                FirstRecord := false;
            end;
            ResultBuilder.AppendLine(RowBuilder.ToText());
        end;

        exit(ResultBuilder.ToText());
    end;

    local procedure FormatTokenValue(Token: JsonToken): Text
    var
        ValueText: Text;
    begin
        if Token.IsValue() then begin
            if Token.AsValue().IsNull() or Token.AsValue().IsUndefined() then
                exit('');
            exit(Token.AsValue().AsText());
        end;
        Token.WriteTo(ValueText);
        exit(ValueText);
    end;

    // -- List Message Types with filtering + paging --

    local procedure HandleListMessageTypes(Arguments: JsonObject; var ResultText: Text; var IsError: Boolean)
    var
        MessageType: Enum "Message Type ori";
        MessageTypeInterface: Interface "Msg Interface ori";
        ResultObject: JsonObject;
        ItemsArray: JsonArray;
        ItemObject: JsonObject;
        NamespaceSummary: JsonArray;
        NsObject: JsonObject;
        NamespaceFilter: Text;
        SearchFilter: Text;
        TypeName: Text;
        TypeNameLower: Text;
        SearchLower: Text;
        NsPrefix: Text;
        DotPos: Integer;
        Skip: Integer;
        Take: Integer;
        MatchIndex: Integer;
        TotalMatches: Integer;
        Returned: Integer;
        NsCounts: Dictionary of [Text, Integer];
        NsName: Text;
        NsCount: Integer;
        IsCompact: Boolean;
    begin
        NamespaceFilter := GetTextArg(Arguments, 'namespace');
        SearchFilter := GetTextArg(Arguments, 'search');
        Skip := GetIntArg(Arguments, 'skip', 0);
        Take := GetIntArg(Arguments, 'take', 25);
        SearchLower := LowerCase(SearchFilter);
        MatchIndex := 0;
        Returned := 0;
        IsError := false;

        // No filter params → return namespace summary only
        IsCompact := (NamespaceFilter = '') and (SearchFilter = '') and (Skip = 0);

        foreach MessageType in Enum::"Message Type ori".Ordinals() do begin
            MessageTypeInterface := MessageType;
            if not MessageTypeInterface.IsEnabled() then
                continue;

            TypeName := Enum::"Message Type ori".Names().Get(
                Enum::"Message Type ori".Ordinals().IndexOf(MessageType.AsInteger()));

            // Extract namespace (first segment before '.')
            DotPos := TypeName.IndexOf('.');
            if DotPos > 0 then
                NsPrefix := CopyStr(TypeName, 1, DotPos - 1)
            else
                NsPrefix := TypeName;

            // Always count namespaces for the summary
            if NsCounts.ContainsKey(NsPrefix) then
                NsCounts.Set(NsPrefix, NsCounts.Get(NsPrefix) + 1)
            else
                NsCounts.Add(NsPrefix, 1);

            if IsCompact then
                continue;

            // Apply namespace filter
            if (NamespaceFilter <> '') and (NsPrefix <> NamespaceFilter) then
                continue;

            // Apply search filter on name + description
            if SearchFilter <> '' then begin
                TypeNameLower := LowerCase(TypeName);
                if not TypeNameLower.Contains(SearchLower) then
                    if not LowerCase(MessageTypeInterface.GetDescription()).Contains(SearchLower) then
                        continue;
            end;

            TotalMatches += 1;

            // Apply paging
            if MatchIndex < Skip then begin
                MatchIndex += 1;
                continue;
            end;
            if Returned >= Take then begin
                MatchIndex += 1;
                continue;
            end;
            MatchIndex += 1;

            Clear(ItemObject);
            ItemObject.Add('name', TypeName);
            ItemObject.Add('description', MessageTypeInterface.GetDescription());
            ItemObject.Add('direction', Enum::"Msg Direction ori".Names().Get(
                Enum::"Msg Direction ori".Ordinals().IndexOf(
                    MessageTypeInterface.GetMessageDirection().AsInteger())));
            ItemsArray.Add(ItemObject);
            Returned += 1;
        end;

        ResultObject.Add('status', 'Success');

        // Always include namespace summary
        foreach NsName in NsCounts.Keys() do begin
            NsCount := NsCounts.Get(NsName);
            Clear(NsObject);
            NsObject.Add('namespace', NsName);
            NsObject.Add('count', NsCount);
            NamespaceSummary.Add(NsObject);
        end;
        ResultObject.Add('namespaces', NamespaceSummary);

        if not IsCompact then begin
            ResultObject.Add('result', ItemsArray);
            ResultObject.Add('totalMatches', TotalMatches);
            ResultObject.Add('returned', Returned);
            ResultObject.Add('skip', Skip);
            ResultObject.Add('hasMore', TotalMatches > (Skip + Returned));
        end;

        ResultObject.Add('usage', 'Use namespace or search to filter. Call get_message_type_help for detailed usage of a specific type.');
        ResultObject.WriteTo(ResultText);
    end;

    // -- Tool Registry --

    local procedure BuildToolRegistry()
    begin
        Clear(ToolRegistry);
        AddTool('invoke_message_type', 'Invokes any Bifrost message type. Use list_message_types to discover available types, then get_message_type_help for usage details.',
            '{"type":"object","properties":{"type":{"type":"string","description":"Bifrost message type name (e.g. Data.Records.Get)"},"data":{"type":"string","description":"JSON request payload. May contain {{blob:<guid>}} references."},"subject":{"type":"string","description":"Optional subject (record key, GUID, document number)."},"format":{"type":"string","enum":["json","csv"],"description":"Response format. csv = pipe-delimited rows (fewer tokens). Default: json."}},"required":["type"]}');
        AddTool('list_message_types', 'Lists enabled message types. No params = namespace overview (compact). Add namespace/search to drill in.',
            '{"type":"object","properties":{"namespace":{"type":"string","description":"Filter by namespace prefix (e.g. Sales, Help, Finance)."},"search":{"type":"string","description":"Filter types whose name or description contains this text."},"skip":{"type":"integer","description":"Paging offset (default 0)."},"take":{"type":"integer","description":"Max results (default 25)."}}}');
        AddTool('get_message_type_help', 'Gets detailed help for a specific message type — parameters, examples, and usage patterns.',
            '{"type":"object","properties":{"messageType":{"type":"string","description":"The message type to get help for (e.g. Data.Records.Get)."}},"required":["messageType"]}');
        AddTool('get_records', 'Reads records from a BC table with optional filter, field selection, and paging.',
            '{"type":"object","properties":{"tableName":{"type":"string","description":"BC table name."},"tableView":{"type":"string","description":"BC tableView filter."},"fieldNumbers":{"type":"array","items":{"type":"integer"},"description":"Field numbers to return. FlowFields are calculated only when listed here."},"skip":{"type":"integer","description":"Paging offset (default 0)."},"take":{"type":"integer","description":"Max records (default 50). Use 5-10 for exploration, more only when needed."},"format":{"type":"string","enum":["json","csv"],"description":"Response format. csv = pipe-delimited rows (fewer tokens). Default: json."}},"required":["tableName"]}');
        AddTool('set_records', 'Creates or updates records in a BC table.',
            '{"type":"object","properties":{"tableName":{"type":"string","description":"BC table name."},"records":{"type":"array","description":"Array of record objects with field values."}},"required":["tableName","records"]}');
        AddTool('get_record_ids', 'Returns {id, modifiedAt} pairs for records in a BC table.',
            '{"type":"object","properties":{"tableName":{"type":"string","description":"BC table name."},"tableView":{"type":"string","description":"BC tableView filter."},"skip":{"type":"integer"},"take":{"type":"integer"},"format":{"type":"string","enum":["json","csv"],"description":"Response format. csv = pipe-delimited rows. Default: json."}},"required":["tableName"]}');
        AddTool('get_blob', 'Reads a blob reference and returns its content.',
            '{"type":"object","properties":{"ref":{"type":"string","description":"Blob reference ({{blob:<guid>}}) to read."},"maxChars":{"type":"integer","description":"Max characters to return (default 20000)."}},"required":["ref"]}');
        AddTool('set_blob', 'Stores content in the blob store and returns a {{blob:<guid>}} reference.',
            '{"type":"object","properties":{"content":{"type":"string","description":"Text or base64 content to store."},"contentType":{"type":"string","description":"MIME type (default: text/plain)."}},"required":["content"]}');
        AddTool('list_blobs', 'Lists all blob references in the current session.',
            '{"type":"object","properties":{}}');
        AddTool('delete_blobs', 'Deletes blob references to free memory. Pass [''*''] to clear all.',
            '{"type":"object","properties":{"refs":{"type":"array","items":{"type":"string"},"description":"Blob references to delete."}},"required":["refs"]}');
        AddTool('download_blob', 'Downloads a blob to the user''s device via the browser save-as dialog. Requires an interactive BC session.',
            '{"type":"object","properties":{"ref":{"type":"string","description":"Blob reference ({{blob:<guid>}}) to download."},"filename":{"type":"string","description":"Suggested filename (e.g. Statement.pdf)."}},"required":["ref"]}');
        AddTool('get_user_memory', 'Gets a user memory entry.',
            '{"type":"object","properties":{"id":{"type":"string","description":"Memory entry ID."},"description":{"type":"string","description":"Memory description to search for."}}}');
        AddTool('set_user_memory', 'Saves a user memory entry.',
            '{"type":"object","properties":{"id":{"type":"string","description":"Memory entry ID."},"description":{"type":"string","description":"Short description."},"memory":{"type":"string","description":"Memory content."}}}');
        AddTool('get_page_url', 'Returns a clickable deep-link URL to a BC page or record card.',
            '{"type":"object","properties":{"tableName":{"type":"string","description":"BC table name (e.g. Customer)."},"systemId":{"type":"string","description":"Record SystemId (GUID)."}},"required":["tableName","systemId"]}');
        AddTool('get_record_count', 'Returns the number of records in a BC table matching an optional filter. Lightweight — no record data returned.',
            '{"type":"object","properties":{"tableName":{"type":"string","description":"BC table name."},"tableView":{"type":"string","description":"Optional BC tableView filter."}},"required":["tableName"]}');
        AddTool('get_totals', 'Aggregates Decimal fields across matching records using CalcSums.',
            '{"type":"object","properties":{"tableName":{"type":"string","description":"BC table name."},"fieldNumbers":{"type":"array","items":{"type":"integer"},"description":"Decimal field numbers to sum."},"tableView":{"type":"string","description":"Optional tableView filter."},"format":{"type":"string","enum":["json","csv"],"description":"Response format. csv = pipe-delimited rows. Default: json."}},"required":["tableName","fieldNumbers"]}');
        AddTool('find_entries', 'Finds all related ledger entries for a document (Navigate). Returns table names and record counts.',
            '{"type":"object","properties":{"documentNo":{"type":"string","description":"Document number to find entries for."},"postingDate":{"type":"string","description":"Posting date (YYYY-MM-DD) to narrow the search."},"format":{"type":"string","enum":["json","csv"],"description":"Response format. csv = pipe-delimited rows. Default: json."}},"required":["documentNo"]}');
        AddTool('get_fields', 'Returns field metadata (number, name, jsonKey, type, class) for a BC table. Use to discover fieldNumbers for get_records/get_totals, or jsonKey names for primaryKey objects.',
            '{"type":"object","properties":{"tableName":{"type":"string","description":"BC table name or number."},"format":{"type":"string","enum":["json","csv"],"description":"Response format. csv = pipe-delimited rows. Default: json."}},"required":["tableName"]}');
        AddTool('search_tables', 'Searches for BC tables by namespace or name. Always filter — unfiltered returns thousands of rows.',
            '{"type":"object","properties":{"tableName":{"type":"string","description":"Table name or number to look up. Omit for namespace-filtered search."},"namespaceFilter":{"type":"string","description":"AL namespace filter with wildcards (e.g. Microsoft.Sales.*)"},"format":{"type":"string","enum":["json","csv"],"description":"Response format. csv = pipe-delimited rows. Default: json."}},"required":[]}');
        AddTool('get_next_line_no', 'Returns the next available Line No. for a document line table (e.g. Sales Line). Required before inserting a new line via set_records.',
            '{"type":"object","properties":{"tableName":{"type":"string","description":"Line table name (e.g. Sales Line, Purchase Line)."},"primaryKey":{"type":"object","description":"Parent document PK fields using jsonKey names (e.g. {\"DocumentType\":1,\"DocumentNo_\":\"S-ORD101001\"})."},"id":{"type":"string","description":"SystemId of any existing line under the parent (alternative to primaryKey)."},"increment":{"type":"integer","description":"Line number step (default 10000)."}},"required":["tableName"]}');
        ToolsBuilt := true;
    end;

    local procedure AddTool(ToolName: Text; Description: Text; InputSchemaJson: Text)
    var
        ToolObject: JsonObject;
        SchemaObject: JsonObject;
    begin
        ToolObject.Add('name', ToolName);
        ToolObject.Add('description', Description);
        SchemaObject.ReadFrom(InputSchemaJson);
        ToolObject.Add('inputSchema', SchemaObject);
        ToolRegistry.Add(ToolObject);
    end;

    // -- JSON Helpers --

    local procedure GetTextArg(Args: JsonObject; PropertyName: Text): Text
    var
        Token: JsonToken;
    begin
        if Args.Get(PropertyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsText());
    end;

    local procedure GetIntArg(Args: JsonObject; PropertyName: Text; DefaultValue: Integer): Integer
    var
        Token: JsonToken;
    begin
        if Args.Get(PropertyName, Token) then
            if Token.IsValue() then
                exit(Token.AsValue().AsInteger());
        exit(DefaultValue);
    end;

    local procedure ExtractJsonProperty(JsonText: Text; PropertyName: Text): Text
    var
        JObject: JsonObject;
        Token: JsonToken;
    begin
        if JObject.ReadFrom(JsonText) then
            if JObject.Get(PropertyName, Token) then
                if Token.IsValue() then
                    if not Token.AsValue().IsNull() and not Token.AsValue().IsUndefined() then
                        exit(Token.AsValue().AsText());
    end;

    local procedure ExtractLanguageName(WhoAmIJson: Text): Text
    var
        JObject: JsonObject;
        PersonalizationToken: JsonToken;
        PersonalizationObject: JsonObject;
        LanguageToken: JsonToken;
    begin
        if not JObject.ReadFrom(WhoAmIJson) then
            exit('');
        if JObject.Get('personalization', PersonalizationToken) then
            if PersonalizationToken.IsObject() then begin
                PersonalizationObject := PersonalizationToken.AsObject();
                if PersonalizationObject.Get('languageName', LanguageToken) then
                    if LanguageToken.IsValue() then
                        exit(LanguageToken.AsValue().AsText());
            end;
    end;
}
