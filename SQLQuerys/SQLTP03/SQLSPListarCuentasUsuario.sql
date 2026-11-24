USE TareaAhorros;
GO

-- Ejemplo de ejecucion:
-- DECLARE @resultCode INT;
-- EXEC dbo.ListarCuentasUsuario
--     @inIdUsuario = 1
--     , @outResultCode = @resultCode OUTPUT;

CREATE OR ALTER PROCEDURE dbo.ListarCuentasUsuario
    @inIdUsuario INT
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @flagEsAdministrador BIT = 0;

        SET @outResultCode = 0;

        SELECT
            @flagEsAdministrador = u.flagEsAdministrador
        FROM dbo.Usuario AS u
        WHERE (u.Id = @inIdUsuario);

        SELECT
            cuenta.Id
            , cuenta.NumeroCuenta
            , persona.Nombre AS NombreCliente
            , tipoCuenta.Nombre AS TipoCuenta
            , moneda.Simbolo AS SimboloMoneda
            , cuenta.Saldo
            , cuenta.FechaCreacion
        FROM dbo.Cuenta AS cuenta
        INNER JOIN dbo.Persona AS persona
            ON (persona.Id = cuenta.IdCAhorrista)
        INNER JOIN dbo.TipoCuentaAhorro AS tipoCuenta
            ON (tipoCuenta.Id = cuenta.IdTipoCuentaAhorro)
        INNER JOIN dbo.TipoMoneda AS moneda
            ON (moneda.Id = tipoCuenta.IdTipoMoneda)
        WHERE (@flagEsAdministrador = 1)
            OR EXISTS (
                SELECT 1
                FROM dbo.UsuarioPuedeVer AS puedeVer
                WHERE (puedeVer.IdUsuario = @inIdUsuario)
                    AND (puedeVer.IdCuenta = cuenta.Id)
            )
        ORDER BY
            cuenta.NumeroCuenta ASC;
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
