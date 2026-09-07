namespace Origo.Bifrost.LanguageModels;
using Origo.Bifrost;

/// <summary>
/// Single-procedure contract for Bifrost Chat providers.
/// The "Procedure Type" field on the argument record identifies the operation.
/// New operations are added as enum values without changing this interface.
/// </summary>
interface "Bifrost LangModel Provider ori"
{
    /// <summary>
    /// Executes the operation identified by Argument."Procedure Type" against the language
    /// model this provider implements. The caller fills the argument record with the
    /// configuration and input values for the operation; the provider writes its outputs
    /// back onto the same record - "Result Boolean", "Result Integer", the token counts and
    /// the large text values reached through SetResultText, SetErrorMessage and SetModels.
    /// See enum "Bifrost Chat Proc. Type ori" for the list of operations.
    /// </summary>
    /// <param name="Argument">Temporary argument record carrying the operation, its inputs and its outputs.</param>
    procedure Execute(var Argument: Record "Bifrost Chat Argument ori" temporary)
}
