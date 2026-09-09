// Bifrost Bifrost Chat — Control Add-in JavaScript
// Handles the chat UI, message rendering, API key prompt,
// and communication with the AL chat provider.

(function () {
    'use strict';

    var config = {};
    var messages = [];
    var isBusy = false;
    var contextSkillContent = '';
    var statusText = '';
    var pendingToolCalls = [];
    var toolResults = [];
    var currentToolIndex = 0;
    var conversationState = '';

    // Helper to get localized label from config, with English fallback
    function lbl(key, fallback) {
        if (config.labels && config.labels[key]) return config.labels[key];
        return fallback || key;
    }

    // --- DOM helpers ---
    function el(id) { return document.getElementById(id); }

    function escapeHtml(text) {
        var div = document.createElement('div');
        div.appendChild(document.createTextNode(text));
        return div.innerHTML;
    }

    // --- Lightweight Markdown → HTML renderer (for assistant messages) ---
    function renderMarkdown(raw) {
        // Escape HTML entities first (XSS safe)
        var text = escapeHtml(raw);

        // Fenced code blocks (```...```)
        text = text.replace(/```([^`]*?)```/gs, function (_, code) {
            return '<pre class="md-code-block"><code>' + code.trim() + '</code></pre>';
        });

        // Split into lines for block-level processing
        var lines = text.split('\n');
        var html = '';
        var inTable = false;
        var tableHeaderDone = false;
        var inList = false;
        var listType = '';
        var i = 0;

        while (i < lines.length) {
            var line = lines[i];

            // Table detection: line starts with | and has at least 2 |
            var isTableRow = /^\|(.+)\|$/.test(line.trim());
            var isSeparator = /^\|[\s:]*[-]+[\s:]*/.test(line.trim()) && /^[\s|:\-]+$/.test(line.trim());

            if (isTableRow || isSeparator) {
                // Close any open list
                if (inList) { html += '</' + listType + '>'; inList = false; }

                if (!inTable) {
                    html += '<table class="md-table">';
                    inTable = true;
                    tableHeaderDone = false;
                }

                if (isSeparator) {
                    // Skip separator row but mark header as done
                    tableHeaderDone = true;
                    i++;
                    continue;
                }

                // Parse cells
                var cells = line.trim().replace(/^\||\|$/g, '').split('|');
                var tag = (!tableHeaderDone) ? 'th' : 'td';
                var rowClass = (!tableHeaderDone) ? ' class="md-table-header"' : '';
                html += '<tr' + rowClass + '>';
                for (var c = 0; c < cells.length; c++) {
                    html += '<' + tag + '>' + inlineMarkdown(cells[c].trim()) + '</' + tag + '>';
                }
                html += '</tr>';
                i++;
                continue;
            }

            // Close table if we left it
            if (inTable) { html += '</table>'; inTable = false; tableHeaderDone = false; }

            // Headings
            var headingMatch = line.match(/^(#{1,4})\s+(.+)$/);
            if (headingMatch) {
                if (inList) { html += '</' + listType + '>'; inList = false; }
                var level = headingMatch[1].length;
                html += '<h' + level + ' class="md-h">' + inlineMarkdown(headingMatch[2]) + '</h' + level + '>';
                i++;
                continue;
            }

            // Horizontal rule
            if (/^[-*_]{3,}$/.test(line.trim())) {
                if (inList) { html += '</' + listType + '>'; inList = false; }
                html += '<hr class="md-hr">';
                i++;
                continue;
            }

            // Unordered list
            var ulMatch = line.match(/^[\s]*[-*+]\s+(.+)$/);
            if (ulMatch) {
                if (!inList || listType !== 'ul') {
                    if (inList) html += '</' + listType + '>';
                    html += '<ul class="md-list">';
                    inList = true;
                    listType = 'ul';
                }
                html += '<li>' + inlineMarkdown(ulMatch[1]) + '</li>';
                i++;
                continue;
            }

            // Ordered list
            var olMatch = line.match(/^[\s]*(\d+)[.)]\s+(.+)$/);
            if (olMatch) {
                if (!inList || listType !== 'ol') {
                    if (inList) html += '</' + listType + '>';
                    html += '<ol class="md-list">';
                    inList = true;
                    listType = 'ol';
                }
                html += '<li>' + inlineMarkdown(olMatch[2]) + '</li>';
                i++;
                continue;
            }

            // Close list if no longer in one
            if (inList && line.trim() === '') {
                html += '</' + listType + '>';
                inList = false;
            }

            // Empty line → paragraph break
            if (line.trim() === '') {
                html += '<div class="md-break"></div>';
                i++;
                continue;
            }

            // Normal paragraph
            html += '<p class="md-p">' + inlineMarkdown(line) + '</p>';
            i++;
        }

        // Close any open blocks
        if (inTable) html += '</table>';
        if (inList) html += '</' + listType + '>';

        return html;
    }

    // Inline markdown: bold, italic, code, links, emoji shortcodes
    function inlineMarkdown(text) {
        // Inline code
        text = text.replace(/`([^`]+)`/g, '<code class="md-code">$1</code>');
        // Bold
        text = text.replace(/\*\*([^*]+)\*\*/g, '<strong>$1</strong>');
        // Italic
        text = text.replace(/\*([^*]+)\*/g, '<em>$1</em>');
        // Links [text](url)
        text = text.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank" class="md-link">$1</a>');
        return text;
    }

    function scrollToBottom() {
        var container = el('mcp-messages');
        if (container) container.scrollTop = container.scrollHeight;
    }

    // --- Rendering ---
    function renderMessages() {
        var container = el('mcp-messages');
        if (!container) return;

        var html = '';
        for (var i = 0; i < messages.length; i++) {
            var msg = messages[i];
            var content = (msg.role === 'assistant')
                ? renderMarkdown(msg.text)
                : escapeHtml(msg.text);
            html += '<div class="mcp-msg mcp-msg-' + msg.role + '">' +
                '<div class="mcp-bubble">' + content + '</div>' +
                '</div>';
        }
        if (isBusy) {
            var displayStatus = statusText || lbl('thinking', 'Thinking...');
            html += '<div class="mcp-msg mcp-msg-assistant">' +
                '<div class="mcp-thinking"><span class="mcp-spinner"></span> ' + escapeHtml(displayStatus) + '</div>' +
                '</div>';
        }
        container.innerHTML = html;
        scrollToBottom();
    }

    function renderToolTrace(toolTrace) {
        if (!config.debug) return;
        if (!toolTrace || !toolTrace.length) return;
        var container = el('mcp-messages');
        if (!container) return;

        var errors = [];
        for (var i = 0; i < toolTrace.length; i++) {
            if (toolTrace[i].status === 'error' && toolTrace[i].error) {
                errors.push(toolTrace[i]);
            }
        }
        if (errors.length === 0) return;

        var html = '<div class="mcp-msg mcp-msg-system"><div class="mcp-bubble">';
        html += '<strong>' + escapeHtml(lbl('toolErrors', 'Tool errors')) + ':</strong><br>';
        for (var j = 0; j < errors.length; j++) {
            html += '<span style="color:#c00">\u26A0 <strong>' +
                escapeHtml(errors[j].tool) + '</strong>: ' +
                escapeHtml(errors[j].error) + '</span><br>';
        }
        html += '</div></div>';
        container.insertAdjacentHTML('beforeend', html);
        scrollToBottom();
    }

    function showStatus(text) {
        var container = el('mcp-messages');
        if (!container) return;
        container.innerHTML = '<div class="mcp-msg mcp-msg-system">' +
            '<div class="mcp-bubble">' + escapeHtml(text) + '</div></div>';
    }

    function showErrorInChat(errorText) {
        messages.push({ role: 'assistant', text: '\u26A0 ' + errorText });
        renderMessages();
    }

    // --- Startup sequence ---
    function startupSequence() {
        if (config.disabled === true) {
            showDisabledPanel();
            return;
        }

        validateConnection();
    }

    function validateConnection() {
        showStatus(lbl('validatingConnection', 'Validating connection...'));

        // Fire AL event — AL queries Company table and calls ConnectionValidated back
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('ValidateConnection', []);
    }

    function onConnectionReady(connectionResult) {
        if (config.disabled === true) {
            showDisabledPanel();
            return;
        }

        // Provider controls whether API key is needed (e.g. Anthropic=true, Azure OpenAI=false)
        if (config.requiresApiKey !== false && !config.apiKey) {
            showApiKeyPrompt();
            return;
        }

        messages = [];
        isBusy = false;
        renderMessages();
        renderToolTrace([]);

        var welcomeText = lbl('readyToChat', 'Ready to chat.');
        messages.push({ role: 'assistant', text: welcomeText });
        renderMessages();
        enableInput(true);
    }

    function enableInput(enabled) {
        var input = el('mcp-input');
        var btn = el('mcp-send');
        if (input) input.disabled = !enabled;
        if (btn) btn.disabled = !enabled;
    }

    // --- API Communication (routed through AL HttpClient to avoid CORS) ---
    function sendToApi(userText) {
        if (config.disabled === true) {
            enableInput(false);
            showDisabledPanel();
            return;
        }

        if (config.requiresApiKey !== false && !config.apiKey) {
            enableInput(false);
            showApiKeyPrompt();
            return;
        }

        messages.push({ role: 'user', text: userText });
        isBusy = true;
        statusText = lbl('waitingForResponse', 'Waiting for response...');
        renderMessages();

        var payload = {
            messages: messages.map(function (m) { return { role: m.role, content: m.text }; })
        };
        if (config.model) payload.model = config.model;
        if (config.recordContext && config.recordContext.tableId) payload.recordContext = config.recordContext;
        if (contextSkillContent) payload.contextSkill = contextSkillContent;

        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('SubmitChatMessage', [JSON.stringify(payload)]);
    }

    // Called from AL after the proxy returns a response
    function ChatMessageResult(responseJson) {
        try {
            var resp = JSON.parse(responseJson);
            if (resp.error) {
                isBusy = false;
                statusText = '';
                var errMsg = resp.error;
                if (resp.detail) errMsg += '\n\n' + resp.detail;
                showErrorInChat(errMsg);
            } else if (resp.type === 'tool_calls' && resp.toolCalls && resp.toolCalls.length > 0) {
                // Provider returned tool calls — execute them one at a time via AL
                pendingToolCalls = resp.toolCalls;
                toolResults = [];
                currentToolIndex = 0;
                conversationState = resp.conversationState || '';
                executeNextToolCall();
            } else {
                // Final reply (type=reply or legacy format)
                isBusy = false;
                statusText = '';
                messages.push({ role: 'assistant', text: resp.reply || resp.text || '' });
                renderMessages();
                renderToolTrace(resp.toolTrace);
            }
        } catch (e) {
            isBusy = false;
            statusText = '';
            showErrorInChat(lbl('failedToParseResponse', 'Failed to parse response.'));
        }
    }

    function executeNextToolCall() {
        if (currentToolIndex >= pendingToolCalls.length) {
            // All tools executed — send results back to provider for next LLM call
            statusText = lbl('thinking', 'Thinking...');
            renderMessages();
            var resultsJson = JSON.stringify(toolResults);
            Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('ContinueWithToolResults', [conversationState, resultsJson]);
            return;
        }
        var tool = pendingToolCalls[currentToolIndex];
        statusText = '\uD83D\uDD27 ' + (tool.name || 'tool') + '...';
        renderMessages();
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('ExecuteToolCall', [
            tool.id || '',
            tool.name || '',
            JSON.stringify(tool.arguments || {})
        ]);
    }

    function onToolCallResult(resultJson) {
        try {
            var result = JSON.parse(resultJson);
            toolResults.push(result);
        } catch (e) {
            toolResults.push({ id: '', name: '', result: 'Failed to parse tool result', isError: true });
        }
        currentToolIndex++;
        executeNextToolCall();
    }

    // --- Input handling ---
    function handleSend() {
        if (isBusy) return;
        var input = el('mcp-input');
        if (!input) return;
        var text = input.value.trim();
        if (!text) return;
        input.value = '';
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('MessageSubmitted', [text]);
        sendToApi(text);
    }

    function handleKeydown(event) {
        if (event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault();
            handleSend();
        }
    }

    // --- Public API (called from AL) ---
    window.Initialize = function (configJson) {
        // Ensure DOM is built (handles race condition on page reopen where
        // cached scripts execute before BC injects the controlAddIn div)
        if (!el('mcp-messages')) {
            buildUI();
        }
        try {
            config = JSON.parse(configJson);
        } catch (e) {
            config = {};
        }
        contextSkillContent = config.contextSkill || '';
        applyLocalizedStaticText();
        messages = [];
        isBusy = false;
        statusText = '';
        pendingToolCalls = [];
        toolResults = [];
        currentToolIndex = 0;
        conversationState = '';
        enableInput(false);
        startupSequence();
    };

    window.ShowResponse = function (responseJson) {
        try {
            var resp = JSON.parse(responseJson);
            messages.push({ role: 'assistant', text: resp.reply || '' });
            isBusy = false;
            renderMessages();
            renderToolTrace(resp.toolTrace);
        } catch (e) {
            showErrorInChat(lbl('invalidResponseFormat', 'Invalid response format.'));
        }
    };

    window.ShowError = function (errorMessage) {
        isBusy = false;
        showErrorInChat(errorMessage);
    };

    window.SetBusy = function (busy) {
        isBusy = busy;
        if (!busy) statusText = '';
        renderMessages();
    };

    window.UpdateStatus = function (text) {
        if (isBusy) {
            statusText = text || '';
            renderMessages();
        }
    };

    window.ToolCallResult = function (resultJson) {
        onToolCallResult(resultJson);
    };

    window.SetRecordContext = function (tableId, recordSystemId, tableName, caption) {
        var prev = config.recordContext;
        var changed = !prev || prev.recordSystemId !== recordSystemId || prev.tableId !== tableId;
        config.recordContext = { tableId: tableId, recordSystemId: recordSystemId, tableName: tableName || '', caption: caption || '' };
        if (changed && messages.length > 1) {
            // Record changed — clear conversation so the model gets fresh context
            messages = [];
            isBusy = false;
            pendingToolCalls = [];
            toolResults = [];
            currentToolIndex = 0;
            conversationState = '';
            var welcomeText = lbl('readyToChat', 'Ready to chat.');
            messages.push({ role: 'assistant', text: welcomeText });
            renderMessages();
            renderToolTrace([]);
            Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('RecordContextChanged', []);
        }
    };

    window.SetContextSkill = function (contextSkill) {
        contextSkillContent = contextSkill || '';
        config.contextSkill = contextSkillContent;
    };

    window.ConnectionValidated = function (resultJson) {
        try {
            var result = JSON.parse(resultJson);
            onConnectionReady(result);
        } catch (e) {
            onConnectionReady(null);
        }
    };

    window.ChatMessageResult = function (responseJson) {
        ChatMessageResult(responseJson);
    };

    window.ShowApiKeyPrompt = function () {
        showApiKeyPrompt();
    };

    window.RequestChatHistory = function () {
        var historyJson = JSON.stringify(messages);
        Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('ChatHistoryReady', [historyJson]);
    };

    window.RestoreChatHistory = function (historyJson) {
        try {
            var restored = JSON.parse(historyJson);
            if (Array.isArray(restored)) {
                messages = restored;
                renderMessages();
                enableInput(true);
            }
        } catch (e) {
            showErrorInChat(lbl('failedRestoreHistory', 'Failed to restore chat history.'));
        }
    };

    // --- Disabled Panel ---
    function showDisabledPanel() {
        var container = el('mcp-messages');
        if (!container) return;
        var message = config.disabledMessage || lbl('chatDisabled', 'Bifrost Chat is disabled. Assign a Language Model with a provider in your Bifrost User Setup to enable chat.');
        container.innerHTML =
            '<div class="mcp-msg mcp-msg-system">' +
            '<div class="mcp-bubble">' +
            '<p>' + escapeHtml(message) + '</p>' +
            '</div></div>';
        enableInput(false);
    }

    // --- API Key Prompt ---
    function showApiKeyPrompt() {
        var container = el('mcp-messages');
        if (!container) return;

        var keyLabel = config.apiKeyLabel || lbl('apiKeyLabel', 'API Key');
        var instruction = config.apiKeyInstruction || lbl('apiKeyInstruction', 'Enter your key to enable chat.');
        var placeholder = config.apiKeyPlaceholder || '';
        var docsUrl = config.apiKeyDocsUrl || '';
        var docsLinkText = config.apiKeyDocsLinkText || docsUrl;
        var serviceDesc = config.serviceKeyDescription || '';
        var canManageService = config.canManageServiceKey === true;
        var hasServiceKey = config.hasServiceKey === true;

        var docsHtml = docsUrl
            ? ' <a href="' + escapeHtml(docsUrl) + '" target="_blank">' + escapeHtml(docsLinkText) + '</a>'
            : '';

        var html = '<div class="mcp-msg mcp-msg-system"><div class="mcp-bubble">' +
            '<p><strong>' + escapeHtml(keyLabel + ' Required') + '</strong></p>' +
            '<p>' + escapeHtml(instruction) + docsHtml + '</p>';

        if (hasServiceKey && !canManageService) {
            html += '<p style="color:#666;font-size:12px;">' +
                escapeHtml(lbl('serviceKeyExists', 'A shared key is configured. Enter a personal key to override it, or leave empty to use the shared key.')) + '</p>';
        }

        html += '<div style="margin-top:8px;">' +
            '<input id="mcp-apikey-input" type="password" placeholder="' + escapeHtml(placeholder) + '" style="width:100%;padding:6px;font-size:13px;border:1px solid #ccc;border-radius:4px;" />' +
            '</div>' +
            '<button id="mcp-apikey-save" type="button" style="margin-top:8px;padding:6px 16px;font-size:13px;cursor:pointer;">' +
            escapeHtml(lbl('savePersonalKey', 'Save Personal Key')) + '</button>';

        if (canManageService) {
            html += ' <button id="mcp-servicekey-save" type="button" style="margin-top:8px;padding:6px 16px;font-size:13px;cursor:pointer;background:#f0f0f0;border:1px solid #ccc;border-radius:4px;">' +
                escapeHtml(lbl('saveServiceKey', 'Save as Shared Key')) + '</button>';
            if (serviceDesc) {
                html += '<p style="color:#666;font-size:11px;margin-top:4px;">' + escapeHtml(serviceDesc) + '</p>';
            }
        }

        html += '</div></div>';
        container.innerHTML = html;

        var saveBtn = el('mcp-apikey-save');
        if (saveBtn) {
            saveBtn.addEventListener('click', function () {
                var keyInput = el('mcp-apikey-input');
                var key = keyInput ? keyInput.value.trim() : '';
                if (!key) return;
                config.apiKey = key;
                Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('SaveApiKey', [key]);
                onConnectionReady({ reply: lbl('apiKeySaved', 'Personal key saved. You can now chat.') });
            });
        }

        var serviceBtn = el('mcp-servicekey-save');
        if (serviceBtn) {
            serviceBtn.addEventListener('click', function () {
                var keyInput = el('mcp-apikey-input');
                var key = keyInput ? keyInput.value.trim() : '';
                if (!key) return;
                config.apiKey = key;
                Microsoft.Dynamics.NAV.InvokeExtensibilityMethod('SaveServiceApiKey', [key]);
                onConnectionReady({ reply: lbl('serviceKeySaved', 'Shared key saved for all users in this company.') });
            });
        }
    }

    function applyLocalizedStaticText() {
        var input = el('mcp-input');
        var sendBtn = el('mcp-send');

        if (input) {
            input.placeholder = lbl('inputPlaceholder', 'Ask about your Business Central data...');
        }

        if (sendBtn) {
            sendBtn.textContent = lbl('sendBtn', 'Send');
        }
    }

    // --- Build DOM ---
    function buildUI() {
        var root = document.getElementById('controlAddIn');
        if (!root) return;

        root.innerHTML =
            '<div class="bifrost-chat">' +
            '  <div class="mcp-messages" id="mcp-messages"></div>' +
            '  <div class="mcp-composer">' +
            '    <textarea id="mcp-input" placeholder="' + escapeHtml(lbl('inputPlaceholder', 'Ask about your Business Central data...')) + '" rows="2" disabled></textarea>' +
            '    <button id="mcp-send" type="button" disabled>' + escapeHtml(lbl('sendBtn', 'Send')) + '</button>' +
            '  </div>' +
            '</div>';

        el('mcp-send').addEventListener('click', handleSend);
        el('mcp-input').addEventListener('keydown', handleKeydown);
    }

    // Initialize DOM when the script loads (before startup fires ControlReady)
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', buildUI);
    } else {
        buildUI();
    }
})();
