USE TareaAhorros;
GO

-- Ejemplo de ejecucion:
-- DECLARE @outCode INT;
-- EXEC dbo.ListarEstadosCuenta
--     @inIdUsuario = 1
--     , @inIdCuenta = 1
--     , @outResultCode = @outCode OUTPUT;

CREATE OR ALTER PROCEDURE dbo.ListarEstadosCuenta
    @inIdUsuario INT
    , @inIdCuenta INT
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @idCuentaValidada INT;
        DECLARE @flagEsAdministrador BIT = 0;

        SET @outResultCode = 0;

        SELECT
            @flagEsAdministrador = u.flagEsAdministrador
        FROM dbo.Usuario AS u
        WHERE (u.Id = @inIdUsuario);

        SELECT
            @idCuentaValidada = c.Id
        FROM dbo.Cuenta AS c
        WHERE (c.Id = @inIdCuenta)
            AND (
                (@flagEsAdministrador = 1)
                OR EXISTS (
                    SELECT 1
                    FROM dbo.UsuarioPuedeVer AS puedeVer
                    WHERE (puedeVer.IdUsuario = @inIdUsuario)
                        AND (puedeVer.IdCuenta = c.Id)
                )
            );

        IF (@idCuentaValidada IS NULL)
        BEGIN
            SET @outResultCode = 50003;
            RETURN;
        END;

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
        WHERE (ec.IdCuenta = @idCuentaValidada)
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

    SET NOCOUNT OFF;
END;
GO