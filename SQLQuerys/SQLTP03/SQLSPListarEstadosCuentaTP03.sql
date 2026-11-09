USE TareaAhorros;
GO

-- Ejemplo de ejecucion:
-- DECLARE @outCode INT;
-- EXEC dbo.ListarEstadosCuenta
--     @inIdCuenta = 1
--     , @outResultCode = @outCode OUTPUT;

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
            , ec.Id AS IdEstadoCuenta
            , ec.IdCuenta
            , ec.FechaInicio
            , ec.FechaFin
            , ec.SaldoInicial
            , ec.SaldoFinal
            , ec.SaldoMinimo
            , ec.CantOperacionesATM
            , ec.CantOperacionesCajeroHumano
            , (ec.CantTransferenciasEntrantes + ec.CantTransferenciasSalientes) AS CantOperacionesSinpe
            , ec.CantTransferenciasEntrantes
            , ec.CantTransferenciasSalientes
        FROM dbo.EstadoCuenta AS ec
        WHERE (ec.IdCuenta = @inIdCuenta)
        ORDER BY
            ec.FechaFin DESC
            , ec.Id DESC;
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
        SELECT
            ERROR_NUMBER()
            , ERROR_STATE()
            , ERROR_SEVERITY()
            , ERROR_LINE()
            , ERROR_PROCEDURE()
            , ERROR_MESSAGE();

        SET @outResultCode = 50005;
    END CATCH;
END;
GO