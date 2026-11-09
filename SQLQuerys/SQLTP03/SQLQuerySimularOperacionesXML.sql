USE TareaAhorros;
GO

-- 1. Asegurar que ListarCuentasUsuario devuelva cuenta.Id junto con todo lo que ya devolvia en TP2
CREATE OR ALTER PROCEDURE dbo.ListarCuentasUsuario
    @inIdUsuario INT
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET @outResultCode = 0;

        SELECT
            cuenta.Id
            , cuenta.NumeroCuenta
            , tipoCuenta.Nombre AS TipoCuenta
            , moneda.Simbolo AS SimboloMoneda
            , cuenta.Saldo
            , cuenta.FechaCreacion
        FROM dbo.UsuarioPuedeVer AS puedeVer
        INNER JOIN dbo.Cuenta AS cuenta
            ON (cuenta.Id = puedeVer.IdCuenta)
        INNER JOIN dbo.TipoCuentaAhorro AS tipoCuenta
            ON (tipoCuenta.Id = cuenta.IdTipoCuentaAhorro)
        INNER JOIN dbo.TipoMoneda AS moneda
            ON (moneda.Id = tipoCuenta.IdTipoMoneda)
        WHERE (puedeVer.IdUsuario = @inIdUsuario)
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
END;
GO