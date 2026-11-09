USE TareaAhorros;
GO

-- Ejemplo de ejecucion:
-- DECLARE @outCode INT;
-- EXEC dbo.ListarMovimientosEstadoCuenta
--     @inIdEstadoCuenta = 1
--     , @outResultCode = @outCode OUTPUT;

CREATE OR ALTER PROCEDURE dbo.ListarMovimientosEstadoCuenta
    @inIdEstadoCuenta INT
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET @outResultCode = 0;

        SELECT
            m.Id
            , m.Fecha
            , m.Monto
            , tm.Simbolo AS SimboloMoneda
            , tmov.Nombre AS TipoMovimiento
            , m.Descripcion
            , m.NuevoSaldo
        FROM dbo.Movimiento AS m
        INNER JOIN dbo.TipoMovimiento AS tmov
            ON (tmov.Id = m.IdTipoMovimiento)
        INNER JOIN dbo.EstadoCuenta AS ec
            ON (ec.Id = m.IdEstadoCuenta)
        INNER JOIN dbo.Cuenta AS c
            ON (c.Id = ec.IdCuenta)
        INNER JOIN dbo.TipoCuentaAhorro AS tca
            ON (tca.Id = c.IdTipoCuentaAhorro)
        INNER JOIN dbo.TipoMoneda AS tm
            ON (tm.Id = tca.IdTipoMoneda)
        WHERE (m.IdEstadoCuenta = @inIdEstadoCuenta)
        ORDER BY
            m.Fecha ASC
            , m.Id ASC;
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