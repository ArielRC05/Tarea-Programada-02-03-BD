USE TareaAhorros;
GO

-- Ejemplo de ejecucion:
-- DECLARE @outCode INT;
-- EXEC dbo.ConsultarEstadoCuenta
--     @inIdUsuario = 1
--     , @inIdEstadoCuenta = 1
--     , @inIP = '192.168.0.10'
--     , @outResultCode = @outCode OUTPUT;

CREATE OR ALTER PROCEDURE dbo.ConsultarEstadoCuenta
    @inIdUsuario INT
    , @inIdEstadoCuenta INT
    , @inIP VARCHAR(64)
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @idEstadoValidado INT;
        DECLARE @jsonDespues NVARCHAR(MAX);

        SET @outResultCode = 0;

        SELECT
            @idEstadoValidado = ec.Id
        FROM dbo.EstadoCuenta AS ec
        INNER JOIN dbo.UsuarioPuedeVer AS puedeVer
            ON (puedeVer.IdCuenta = ec.IdCuenta)
        WHERE (ec.Id = @inIdEstadoCuenta)
            AND (puedeVer.IdUsuario = @inIdUsuario);

        IF (@idEstadoValidado IS NULL)
        BEGIN
            SET @outResultCode = 50003;
            RETURN;
        END;

        SET @jsonDespues = '{"IdEstadoCuenta":' + CONVERT(VARCHAR(16), @idEstadoValidado) + '}';

        INSERT dbo.Bitacora (
            IdUsuario
            , IdTipoOperacion
            , IP
            , JsonAntes
            , JsonDespues
        )
        SELECT
            @inIdUsuario
            , 7
            , @inIP
            , NULL
            , @jsonDespues;

        SELECT
            ec.Id
            , ec.IdCuenta
            , ec.FechaInicio
            , ec.FechaFin
            , ec.FechaFin AS Fecha
            , ec.SaldoMinimo
            , ec.SaldoInicial
            , ec.SaldoFinal
            , ec.CantOperacionesATM
            , ec.CantOperacionesCajeroHumano
            , (ec.CantTransferenciasEntrantes + ec.CantTransferenciasSalientes) AS CantOperacionesSinpe
            , tm.Simbolo AS SimboloMoneda
        FROM dbo.EstadoCuenta AS ec
        INNER JOIN dbo.Cuenta AS c
            ON (c.Id = ec.IdCuenta)
        INNER JOIN dbo.TipoCuentaAhorro AS tca
            ON (tca.Id = c.IdTipoCuentaAhorro)
        INNER JOIN dbo.TipoMoneda AS tm
            ON (tm.Id = tca.IdTipoMoneda)
        WHERE (ec.Id = @idEstadoValidado);
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