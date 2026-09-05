namespace Origo.Bifrost.Bragi;
using Origo.Bifrost;

/// <summary>
/// Single-procedure contract for Bifrost Chat providers.
/// The "Procedure Type" field on the argument record identifies the operation.
/// New operations are added as enum values without changing this interface.
/// </summary>
interface "Bifrost LangModel Provider ori"
{
    procedure Execute(var Argument: Record "Bifrost Chat Argument ori" temporary)
}
