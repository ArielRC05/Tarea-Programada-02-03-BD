USE TareaAhorros;
GO

CREATE OR ALTER PROCEDURE dbo.ConsultarEstadoCuenta
    @inIdEstadoCuenta INT
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET @outResultCode = 0;

        SELECT
            ec.Id
            , ec.IdCuenta
            , ec.FechaInicio
            , ec.FechaFin AS Fecha
            , ec.SaldoMinimo
            , ec.SaldoInicial
            , ec.SaldoFinal
            , ec.CantOperacionesATM
            , ec.CantOperacionesCajeroHumano
            , (ec.CantTransferenciasEntrantes + ec.CantTransferenciasSalientes) AS CantOperacionesSinpe
            , tm.Simbolo AS SimboloMoneda
        FROM dbo.EstadoCuenta ec
        INNER JOIN dbo.Cuenta c
            ON c.Id = ec.IdCuenta
        INNER JOIN dbo.TipoCuentaAhorro tca
            ON tca.Id = c.IdTipoCuentaAhorro
        INNER JOIN dbo.TipoMoneda tm
            ON tm.Id = tca.IdTipoMoneda
        WHERE ec.Id = @inIdEstadoCuenta;
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