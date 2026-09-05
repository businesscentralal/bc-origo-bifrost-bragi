namespace Origo.Bifrost.Bragi;
using Origo.Bifrost;

/// <summary>
/// Provider-neutral JavaScript control add-in that embeds an Bifrost chat
/// interface in BC pages. The hosting page (or provider extension) supplies
/// all provider-specific configuration (API endpoint, labels, API key URL,
/// model identifier, etc.) through the Initialize ConfigJson payload.
/// </summary>

controladdin "Bifrost Chat ori"
{
    RequestedHeight = 500;
    MinimumHeight = 300;
    RequestedWidth = 400;
    MinimumWidth = 300;
    VerticalStretch = true;
    VerticalShrink = true;
    HorizontalStretch = true;
    HorizontalShrink = true;

    Scripts = 'src/BifrostChat/ControlAddIn/scripts/BifrostChat.js';
    StartupScript = 'src/BifrostChat/ControlAddIn/scripts/startup.js';
    StyleSheets = 'src/BifrostChat/ControlAddIn/styles/BifrostChat.css';

    /// <summary>
    /// Fired when the control add-in is ready and the DOM is loaded.
    /// The hosting page should call Initialize() in response.
    /// </summary>
    event ControlReady();

    /// <summary>
    /// Fired when the user submits a message in the chat input.
    /// </summary>
    /// <param name="UserMessage">The text entered by the user.</param>
    event MessageSubmitted(UserMessage: Text);

    /// <summary>
    /// Initializes the chat control with configuration needed to call the API.
    /// </summary>
    /// <param name="ConfigJson">JSON object with apiKey, companyId, lcid, mcpUrl, systemPrompt, model, labels, apiKeyDocsUrl, apiKeyDocsLinkText, apiKeyPlaceholder.</param>
    procedure Initialize(ConfigJson: Text);

    /// <summary>
    /// Displays an assistant response in the chat panel.
    /// </summary>
    /// <param name="ResponseJson">JSON object with reply, toolTrace, memoryCount, usage.</param>
    procedure ShowResponse(ResponseJson: Text);

    /// <summary>
    /// Displays an error message in the chat panel.
    /// </summary>
    /// <param name="ErrorMessage">The error text to display.</param>
    procedure ShowError(ErrorMessage: Text);

    /// <summary>
    /// Sets the busy state indicator (shows/hides thinking spinner).
    /// </summary>
    /// <param name="IsBusy">True to show thinking state, false to clear it.</param>
    procedure SetBusy(IsBusy: Boolean);

    /// <summary>
    /// Shows an ephemeral status message in the thinking area (e.g., tool name being called).
    /// Replaces the current status text without adding a chat bubble.
    /// </summary>
    /// <param name="StatusText">Short status text to display.</param>
    procedure UpdateStatus(StatusText: Text);

    /// <summary>
    /// Returns the result of a single tool execution back to the control.
    /// The control accumulates results and either executes the next tool or
    /// fires ContinueWithToolResults when all tools are done.
    /// </summary>
    /// <param name="ResultJson">JSON: {"id":"...","name":"...","result":"...","isError":false}</param>
    procedure ToolCallResult(ResultJson: Text);

    /// <summary>
    /// Sets the record context so the chat can use Data.Records.Get for BC data.
    /// </summary>
    /// <param name="TableId">The table number of the current record.</param>
    /// <param name="RecordSystemId">The SystemId (GUID) of the current record.</param>
    /// <param name="TableName">The name of the source table (e.g. Purchase Header).</param>
    /// <param name="Caption">Human-readable record identifier (e.g. Invoice R00007).</param>
    procedure SetRecordContext(TableId: Integer; RecordSystemId: Text; TableName: Text; Caption: Text);

    /// <summary>
    /// Sets additional context-specific skill guidance to append to the chat prompt.
    /// This is combined with the user's role skill from setup.
    /// </summary>
    /// <param name="ContextSkill">Markdown guidance for the current record context.</param>
    procedure SetContextSkill(ContextSkill: Text);

    /// <summary>
    /// Fired when the user submits a chat message and the control needs AL
    /// to proxy the API call (avoiding CORS restrictions in the iframe).
    /// </summary>
    /// <param name="PayloadJson">JSON payload to POST to the provider proxy endpoint.</param>
    event SubmitChatMessage(PayloadJson: Text);

    /// <summary>
    /// Returns the provider proxy response to the control after AL completes the HTTP call.
    /// </summary>
    /// <param name="ResponseJson">JSON response from the proxy (reply, toolTrace, error).</param>
    procedure ChatMessageResult(ResponseJson: Text);

    /// <summary>
    /// Fired when the user enters their provider API key in the setup prompt.
    /// AL persists it in per-user IsolatedStorage.
    /// </summary>
    /// <param name="ApiKey">The provider API key entered by the user.</param>
    event SaveApiKey(ApiKey: Text);

    /// <summary>
    /// Fired when an admin sets the shared service-level API key.
    /// AL persists it in DataScope::Module IsolatedStorage.
    /// </summary>
    /// <param name="ApiKey">The shared API key entered by the admin.</param>
    event SaveServiceApiKey(ApiKey: Text);

    /// <summary>
    /// Shows the API key input prompt when no key is configured.
    /// Called from AL or triggered by the control's startup flow.
    /// </summary>
    procedure ShowApiKeyPrompt();

    /// <summary>
    /// Requests the current chat history from the control.
    /// The control responds asynchronously by firing the ChatHistoryReady event.
    /// </summary>
    procedure RequestChatHistory();

    /// <summary>
    /// Restores a previously exported chat history into the control.
    /// Messages are parsed from JSON and rendered in the chat panel.
    /// </summary>
    /// <param name="HistoryJson">JSON array of message objects with role and text properties.</param>
    procedure RestoreChatHistory(HistoryJson: Text);

    /// <summary>
    /// Fired by the control in response to RequestChatHistory() with the serialized message history.
    /// </summary>
    /// <param name="HistoryJson">JSON array of message objects [{role, text}, ...].</param>
    event ChatHistoryReady(HistoryJson: Text);

    /// <summary>
    /// Fired by the control on startup to validate that BC is reachable.
    /// AL handles this by querying the Company table and calling ConnectionValidated.
    /// </summary>
    event ValidateConnection();
    /// <summary>
    /// Fired by the control when the LLM response contains tool calls.
    /// AL executes the tool via Bifrost MCP Tool Server and calls ToolCallResult.
    /// </summary>
    /// <param name="ToolCallId">Provider-assigned tool call identifier.</param>
    /// <param name="ToolName">The tool name to execute.</param>
    /// <param name="ArgumentsJson">JSON object with the tool arguments.</param>
    event ExecuteToolCall(ToolCallId: Text; ToolName: Text; ArgumentsJson: Text);

    /// <summary>
    /// Fired by the control after all tool results are collected.
    /// AL forwards the results to the provider's ContinueWithToolResults and
    /// returns the next response via ChatMessageResult.
    /// </summary>
    /// <param name="ConversationState">Opaque provider state from the previous LLM response.</param>
    /// <param name="ToolResultsJson">JSON array of tool results.</param>
    event ContinueWithToolResults(ConversationState: Text; ToolResultsJson: Text);

    /// <summary>
    /// Fired when the record context changes (user navigated to a different record).
    /// AL clears the ToolServer session so the next chat gets fresh context.
    /// </summary>
    event RecordContextChanged();

    /// <summary>
    /// Returns the connection validation result to the control.
    /// </summary>
    /// <param name="ResponseJson">JSON with companies array and current company name.</param>
    procedure ConnectionValidated(ResponseJson: Text);
}
