namespace Origo.Bifrost.Bragi;
using Origo.Bifrost;

using System.AI;

/// <summary>
/// Implements the AOAI Function interface for dynamic tool registration.
/// Each instance holds one tool's name, description, and parameter schema.
/// </summary>
codeunit 10035392 "Copilot AOAI Func Impl ori" implements "AOAI Function"
{
    Access = Internal;

    var
        ToolName: Text;
        ToolDescription: Text;
        ToolSchema: JsonObject;

    internal procedure SetToolData(NewName: Text; NewDescription: Text; NewSchema: JsonObject)
    begin
        ToolName := NewName;
        ToolDescription := NewDescription;
        ToolSchema := NewSchema;
    end;

    procedure GetName(): Text
    begin
        exit(ToolName);
    end;

    procedure GetPrompt(): JsonObject
    var
        Prompt: JsonObject;
        FunctionDef: JsonObject;
    begin
        FunctionDef.Add('name', ToolName);
        if ToolDescription <> '' then
            FunctionDef.Add('description', ToolDescription);
        FunctionDef.Add('parameters', ToolSchema);

        Prompt.Add('type', 'function');
        Prompt.Add('function', FunctionDef);
        exit(Prompt);
    end;

    procedure Execute(Arguments: JsonObject): Variant
    begin
        // Manual tool invoke — execution handled by Bifrost MCP Tool Server
        exit('');
    end;
}
