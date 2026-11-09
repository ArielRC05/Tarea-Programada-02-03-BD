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
            m.Fecha
            , m.Monto
            , m.Descripcion
            , m.NuevoSaldo
        FROM dbo.Movimiento AS m
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