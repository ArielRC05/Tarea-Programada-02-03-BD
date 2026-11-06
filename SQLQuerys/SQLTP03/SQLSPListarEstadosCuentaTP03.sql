USE TareaAhorros;
GO

CREATE OR ALTER PROCEDURE dbo.ListarEstadosCuenta
    @inIdCuenta INT
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET @outResultCode = 0;

        SELECT
            ec.Id
            , ec.FechaInicio
            , ec.FechaFin
            , ec.SaldoInicial
            , ec.SaldoFinal
            , ec.SaldoMinimo
        FROM dbo.EstadoCuenta ec
        WHERE ec.IdCuenta = @inIdCuenta
        ORDER BY ec.FechaFin DESC, ec.Id DESC;
    END TRY
    BEGIN CATCH
        INSERT dbo.DBErrors (
            NumeroError
            , EstadoError
            , SeveridadError
            , LineaDeError
            , ProcedureError
            , MensajeError
        )
        SELECT ERROR_NUMBER()
            , ERROR_STATE()
            , ERROR_SEVERITY()
            , ERROR_LINE()
            , ERROR_PROCEDURE()
            , ERROR_MESSAGE();

        SET @outResultCode = 50005;
    END CATCH;
END;
GO