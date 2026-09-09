namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

/// <summary>
/// Returns the default skill content for the Copilot language model.
/// Embedded in code so it stays in sync with the internal tool server.
/// </summary>
codeunit 10035395 "Copilot Default Skill ori"
{
    Access = Internal;

    internal procedure GetSkillText() SkillText: Text
    var
        Skill: TextBuilder;
    begin
        Skill.AppendLine('# Copilot Skill — Bifrost Internal Tool Server');
        Skill.AppendLine('');
        Skill.AppendLine('## Table and Field Names');
        Skill.AppendLine('- Table and field names are ALWAYS in English, even on non-English BC instances.');
        Skill.AppendLine('- BC uses abbreviations: "Cust. Ledger Entry" (NOT "Customer Ledger Entry"), "Gen. Journal Line", "G/L Entry".');
        Skill.AppendLine('- NEVER guess table or field names. Call search_tables to find tables and get_fields to find field names before using them.');
        Skill.AppendLine('- To find related tables (e.g. ledger entries for a customer), call get_fields on the source table, then use Help.TableRelations.Get to discover which tables reference it.');
        Skill.AppendLine('');
        Skill.AppendLine('## tableView Syntax');
        Skill.AppendLine('- Full syntax: WHERE(Field Name=CONST(value)) or WHERE(Field Name=FILTER(pattern))');
        Skill.AppendLine('- CONST for exact single value. FILTER for ranges, wildcards, or multiple values.');
        Skill.AppendLine('- Examples:');
        Skill.AppendLine('  - WHERE(Customer No.=CONST(10000))');
        Skill.AppendLine('  - WHERE(Posting Date=FILTER(01/01/2025..12/31/2025))');
        Skill.AppendLine('  - WHERE(Document Type=CONST(1),Sell-to Customer No.=CONST(10000))');
        Skill.AppendLine('- Option/Enum fields: always use integer ordinals (e.g. Document Type=CONST(1) for Order). Never use text captions in filters.');
        Skill.AppendLine('');
        Skill.AppendLine('## Record Context');
        Skill.AppendLine('- When the user says "this", "here", "the customer", or refers to the current page, they mean the record in RECORD CONTEXT.');
        Skill.AppendLine('- Use its tableId and recordSystemId with get_records to fetch data. Do not ask for clarification when context is clear.');
        Skill.AppendLine('- To find entries for a record, use the record''s primary key value to filter the related ledger table (e.g. WHERE(Customer No.=CONST(<no>)) on Cust. Ledger Entry).');
        Skill.AppendLine('');
        Skill.AppendLine('## Error Recovery');
        Skill.AppendLine('- If a table name fails, call search_tables with a partial name to find the correct one.');
        Skill.AppendLine('- If a field name fails, call get_fields on the table to discover the correct field name.');
        Skill.AppendLine('- Never ask the user to fix technical errors — resolve them yourself using discovery tools.');

        SkillText := Skill.ToText();
    end;
}
