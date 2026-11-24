USE TareaAhorros;
GO

-- Ejemplo de ejecucion:
-- DECLARE @outCode INT;
-- EXEC dbo.ListarMovimientosEstadoCuenta
--     @inIdUsuario = 1
--     , @inIdEstadoCuenta = 1
--     , @inIP = '192.168.0.10'
--     , @outResultCode = @outCode OUTPUT;

CREATE OR ALTER PROCEDURE dbo.ListarMovimientosEstadoCuenta
    @inIdUsuario INT
    , @inIdEstadoCuenta INT
    , @inIP VARCHAR(64)
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @idEstadoValidado INT;
        DECLARE @flagEsAdministrador BIT = 0;
        DECLARE @jsonDespues NVARCHAR(MAX);

        SET @outResultCode = 0;

        SELECT
            @flagEsAdministrador = u.flagEsAdministrador
        FROM dbo.Usuario AS u
        WHERE (u.Id = @inIdUsuario);

        SELECT
            @idEstadoValidado = ec.Id
        FROM dbo.EstadoCuenta AS ec
        WHERE (ec.Id = @inIdEstadoCuenta)
            AND (
                (@flagEsAdministrador = 1)
                OR EXISTS (
                    SELECT 1
                    FROM dbo.UsuarioPuedeVer AS puedeVer
                    WHERE (puedeVer.IdUsuario = @inIdUsuario)
                        AND (puedeVer.IdCuenta = ec.IdCuenta)
                )
            );

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
            , 8
            , @inIP
            , NULL
            , @jsonDespues;

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
        WHERE (m.IdEstadoCuenta = @idEstadoValidado)
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

    SET NOCOUNT OFF;
END;
GO