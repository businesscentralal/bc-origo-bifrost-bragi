namespace Origo.Bifrost.Bragi;
using Origo.Bifrost;

/// <summary>
/// Identifies the operation to execute on the Bifrost Language Model Provider interface.
/// Adding new values extends the interface without changing its signature.
/// </summary>
enum 10035338 "Bifrost Chat Proc. Type ori"
{
    Extensible = true;

    value(0; " ") { Caption = ' '; }

    // Config-dependent operations
    value(10; IsConfigured) { Caption = 'IsConfigured'; }
    value(11; BuildConfigJson) { Caption = 'BuildConfigJson'; }
    value(12; SendChatMessage) { Caption = 'SendChatMessage'; }
    value(13; ContinueWithToolResults) { Caption = 'ContinueWithToolResults'; }
    value(14; GetAvailableModels) { Caption = 'GetAvailableModels'; }
    value(15; TestConnection) { Caption = 'TestConnection'; }
    value(16; GetTokenUsage) { Caption = 'GetTokenUsage'; }
    value(17; CompletePrompt) { Caption = 'CompletePrompt'; }

    // Provider metadata
    value(100; GetProviderName) { Caption = 'GetProviderName'; }
    value(101; RequiresApiKey) { Caption = 'RequiresApiKey'; }
    value(102; GetApiKeyLabel) { Caption = 'GetApiKeyLabel'; }
    value(103; GetApiKeyInstruction) { Caption = 'GetApiKeyInstruction'; }
    value(104; GetApiKeyPlaceholder) { Caption = 'GetApiKeyPlaceholder'; }
    value(105; GetApiKeyDocsUrl) { Caption = 'GetApiKeyDocsUrl'; }
    value(106; GetApiKeyDocsLinkText) { Caption = 'GetApiKeyDocsLinkText'; }
    value(107; GetServiceKeyDescription) { Caption = 'GetServiceKeyDescription'; }
    value(108; HasServiceKeyPermission) { Caption = 'HasServiceKeyPermission'; }
    value(110; GetMaxToolCount) { Caption = 'GetMaxToolCount'; }
    value(111; SupportsSplitToolExecution) { Caption = 'SupportsSplitToolExecution'; }
    value(112; SupportsModelSelection) { Caption = 'SupportsModelSelection'; }
    value(113; SupportsToolCalling) { Caption = 'SupportsToolCalling'; }
    value(114; HasExternalEndpoint) { Caption = 'HasExternalEndpoint'; }
    value(115; RequiresChatPath) { Caption = 'RequiresChatPath'; }
    value(116; RequiresModelsPath) { Caption = 'RequiresModelsPath'; }
    value(120; GetDefaultBaseUrl) { Caption = 'GetDefaultBaseUrl'; }
    value(121; GetDefaultModel) { Caption = 'GetDefaultModel'; }
    value(122; GetDefaultTimeoutSeconds) { Caption = 'GetDefaultTimeoutSeconds'; }
    value(123; GetDefaultMaxTokens) { Caption = 'GetDefaultMaxTokens'; }
    value(124; GetContextWindowChars) { Caption = 'GetContextWindowChars'; }
    value(125; GetDefaultSkillUrl) { Caption = 'GetDefaultSkillUrl'; }
    value(126; GetDefaultSkillText) { Caption = 'GetDefaultSkillText'; }
}
