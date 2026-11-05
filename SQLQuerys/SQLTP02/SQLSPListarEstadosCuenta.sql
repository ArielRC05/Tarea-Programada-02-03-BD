
--listar los estados de cuenta (los ultimos 8 empezando con el mas reciente)
--Ejemplo de ejecucion
--DECLARE @resultCode INT;
--EXEC dbo.ListarEstadosCuenta
--     @inIdUsuario = 1
--     , @inNumeroCuenta = '11000001'
--     , @inIP = '111.222.0.10'
--     , @outResultCode = @resultCode OUTPUT;

CREATE PROCEDURE dbo.ListarEstadosCuenta
    @inIdUsuario INT
    , @inNumeroCuenta VARCHAR(32)
    , @inIP VARCHAR(64)
    , @outResultCode INT OUTPUT --codigo del resultado
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @idCuenta INT;

        SET @outResultCode = 0;

        SELECT @idCuenta = cuenta.Id --que el usuario pueda ver esa cuenta
        FROM dbo.UsuarioPuedeVer puedeVer
        INNER JOIN dbo.Cuenta cuenta
            ON cuenta.Id = puedeVer.IdCuenta
        WHERE puedeVer.IdUsuario = @inIdUsuario
            AND cuenta.NumeroCuenta = @inNumeroCuenta;

        IF (@idCuenta IS NULL)
        BEGIN
            SET @outResultCode = 50003; --50003 error en la cuenta (no es del usuario)
        END
        ELSE
        BEGIN
            INSERT dbo.Bitacora (
                IdUsuario
                , IdTipoOperacion
                , IP
                , JsonAntes
                , JsonDespues
            )
            SELECT @inIdUsuario
                , 7 --7 consultar el estado de cuenta
                , @inIP
                , NULL
                , NULL;

            SELECT estado.Id AS IdEstadoCuenta
                , estado.FechaInicio
                , estado.FechaFin --fecha de emision del estado
                , estado.SaldoInicial
                , estado.SaldoFinal
                , estado.SaldoMinimo
                , estado.Intereses
                , estado.CantRetiros
                , estado.CantDepositos
                , estado.CantTransferenciasEntrantes
                , estado.CantTransferenciasSalientes
            FROM dbo.EstadoCuenta estado
            WHERE estado.IdCuenta = @idCuenta
                AND ((SELECT COUNT(posterior.Id) --solo los que tienen menos de 8 estados mas recientes
                      FROM dbo.EstadoCuenta posterior
                      WHERE posterior.IdCuenta = estado.IdCuenta
                          AND posterior.FechaFin > estado.FechaFin) < 8)
            ORDER BY estado.FechaFin DESC;
        END;
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