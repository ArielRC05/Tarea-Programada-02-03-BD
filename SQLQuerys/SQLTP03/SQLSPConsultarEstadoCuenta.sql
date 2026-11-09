USE TareaAhorros;
GO

-- Ejemplo de ejecucion:
-- DECLARE @outCode INT;
-- EXEC dbo.ConsultarEstadoCuenta
--     @inIdEstadoCuenta = 1
--     , @outResultCode = @outCode OUTPUT;

CREATE OR ALTER PROCEDURE dbo.ConsultarEstadoCuenta
    @inIdEstadoCuenta INT
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET @outResultCode = 0;

        SELECT
            ec.FechaFin AS Fecha
            , ec.SaldoMinimo
            , ec.SaldoInicial
            , ec.SaldoFinal
            , ec.CantOperacionesATM
            , ec.CantOperacionesCajeroHumano
            , (ec.CantTransferenciasEntrantes + ec.CantTransferenciasSalientes) AS CantOperacionesSinpe
        FROM dbo.EstadoCuenta AS ec
        WHERE (ec.Id = @inIdEstadoCuenta);
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