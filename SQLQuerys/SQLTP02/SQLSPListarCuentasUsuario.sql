--listar las cuentas del usuario, para que las vea y tenga (por si ocupa para acceder o ver a cual acceder)
-- Ejemplo de ejecucion:
-- DECLARE @resultCode INT;
-- EXEC dbo.ListarCuentasUsuario
--     @inIdUsuario = 1
--     , @outResultCode = @resultCode OUTPUT;
CREATE PROCEDURE dbo.ListarCuentasUsuario
    @inIdUsuario INT
    , @outResultCode INT OUTPUT -- codigo del resultado
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET @outResultCode = 0;

        SELECT cuenta.NumeroCuenta
            , tipoCuenta.Nombre AS TipoCuenta
            , moneda.Simbolo AS SimboloMoneda
            , cuenta.Saldo
            , cuenta.FechaCreacion
        FROM dbo.UsuarioPuedeVer puedeVer
        INNER JOIN dbo.Cuenta cuenta
            ON cuenta.Id = puedeVer.IdCuenta --buscar cuenta id
        INNER JOIN dbo.TipoCuentaAhorro tipoCuenta
            ON tipoCuenta.Id = cuenta.IdTipoCuentaAhorro --buscar tipo de cuenta
        INNER JOIN dbo.TipoMoneda moneda
            ON moneda.Id = tipoCuenta.IdTipoMoneda --buscar tipo moneda
        WHERE puedeVer.IdUsuario = @inIdUsuario
        ORDER BY cuenta.NumeroCuenta;
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

        SET @outResultCode = 50001; --50001 es error de plataforma
    END CATCH;
END;
GO
