USE TareaAhorros
GO
--Ejemplo de ejecucion:
--DECLARE @r INT;
--EXEC dbo.AplicarMovimiento
--    @inFechaOperacion = '2026-03-01'
--    , @inNumeroCuenta = '11000001'
--    , @inNombreTipoMovimiento = 'Deposito Ventana'
--    , @inMonto = 250000.00
--    , @inDescripcion = 'Prueba'
--    , @outResultCode = @r OUTPUT;
--SELECT @r AS outResultCode;

CREATE OR ALTER PROCEDURE dbo.AplicarMovimiento
    @inFechaOperacion DATE
    , @inNumeroCuenta VARCHAR(32)
    , @inNombreTipoMovimiento VARCHAR(64)
    , @inMonto DECIMAL(18,2)
    , @inDescripcion VARCHAR(256)
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET @outResultCode = 0

        DECLARE @IdCuenta INT
            , @SaldoActual DECIMAL(18,2)
            , @AcumuladoSinpe DECIMAL(18,2)
            , @FechaAcumuladoSinpe DATE
            , @MontoMaxSinpeDiario DECIMAL(18,2)
            , @ComisionSinpe DECIMAL(18,2)
            , @IdTipoMovimiento INT
            , @flagEsCredito BIT
            , @flagGeneraComprobante BIT
            , @flagEsATM BIT
            , @flagEsCajeroHumano BIT
            , @flagEsSinpe BIT
            , @flagEsSinpeEntrante BIT = 0
            , @flagEsSinpeSaliente BIT = 0
            , @flagCobraComisionSinpe BIT = 0
            , @flagEnTransaccion BIT = 0
            , @IdEstadoCuenta INT
            , @NuevoSaldo DECIMAL(18,2)
            , @SaldoFinal DECIMAL(18,2)
            , @NuevoAcumuladoSinpe DECIMAL(18,2)
            , @NuevaFechaAcumuladoSinpe DATE
            , @TextoEmail VARCHAR(512)
            , @IdComprobante INT
            , @IDTIPOMOVCOMISIONSINPE INT = 10;     -- ALAMBRADO, Comision Sinpe

        -- Precalculos y lecturas
        SELECT @IdCuenta = C.Id
            , @SaldoActual = C.Saldo
            , @AcumuladoSinpe = C.AcumuladosSinpe
            , @FechaAcumuladoSinpe = C.FechaAcumuladosSinpe
            , @MontoMaxSinpeDiario = T.MontoMaxSinpeDiario
            , @ComisionSinpe = T.ComisionSinpe
        FROM dbo.Cuenta C
        INNER JOIN dbo.TipoCuentaAhorro T
            ON C.IdTipoCuentaAhorro = T.Id
        WHERE C.NumeroCuenta = @inNumeroCuenta;

        IF (@IdCuenta IS NULL)
        BEGIN
            SET @outResultCode = 50011; -- la cuenta no existe
            RETURN;
        END;

        SELECT @IdTipoMovimiento = TM.Id
            , @flagEsCredito = TM.flagEsCredito
            , @flagGeneraComprobante = TM.flagGeneraComprobante
            , @flagEsATM = TM.flagEsATM
            , @flagEsCajeroHumano = TM.flagEsCajeroHumano
            , @flagEsSinpe = TM.flagEsSinpe
        FROM dbo.TipoMovimiento TM
        WHERE TM.Nombre = @inNombreTipoMovimiento;

        IF (@IdTipoMovimiento IS NULL)
        BEGIN
            SET @outResultCode = 50012; -- el tipo de movimiento no existe
            RETURN;
        END;

        SELECT @IdEstadoCuenta = E.Id
        FROM dbo.EstadoCuenta E
        WHERE (E.IdCuenta = @IdCuenta)
            AND (E.FechaInicio <= @inFechaOperacion)
            AND (E.FechaFin >= @inFechaOperacion);

        IF (@IdEstadoCuenta IS NULL)
        BEGIN
            SET @outResultCode = 50013; -- no hay estado de cuenta vigente para la fecha
            RETURN;
        END;

        SET @NuevoSaldo = CASE
                            WHEN (@flagEsCredito = 1) THEN @SaldoActual + @inMonto
                            ELSE @SaldoActual - @inMonto
                          END;

        SET @SaldoFinal = @NuevoSaldo; -- cambia solo si hay comision
        SET @NuevoAcumuladoSinpe = @AcumuladoSinpe;
        SET @NuevaFechaAcumuladoSinpe = @FechaAcumuladoSinpe;

        IF (@flagEsSinpe = 1)
        BEGIN
            IF (@flagEsCredito = 1)
            BEGIN
                SET @flagEsSinpeEntrante = 1;
            END
            ELSE
            BEGIN
                SET @flagEsSinpeSaliente = 1;

                IF ((@FechaAcumuladoSinpe IS NULL) OR (@FechaAcumuladoSinpe <> @inFechaOperacion))
                BEGIN
                    SET @NuevoAcumuladoSinpe = 0;   -- es un dia nuevo, el acumulado reinicia
                END;

                SET @NuevoAcumuladoSinpe = @NuevoAcumuladoSinpe + @inMonto;
                SET @NuevaFechaAcumuladoSinpe = @inFechaOperacion;

                IF (@NuevoAcumuladoSinpe > @MontoMaxSinpeDiario)
                BEGIN
                    SET @flagCobraComisionSinpe = 1;
                    SET @SaldoFinal = @NuevoSaldo - @ComisionSinpe;
                END;
            END;
        END;

        SET @TextoEmail = 'Comprobante: Se aplico ' + @inNombreTipoMovimiento
            + ' por ' + CONVERT(VARCHAR(32), @inMonto)
            + ' a su cuenta ' + @inNumeroCuenta
            + ' Su nuevo saldo seria: ' + CONVERT(VARCHAR(32), @NuevoSaldo);

        -- Comprobar que no se ensucio
        IF EXISTS (
            SELECT 1
            FROM dbo.Cuenta C
            WHERE (C.Id = @IdCuenta)
                AND (C.Saldo <> @SaldoActual)
        )
        BEGIN
            SET @outResultCode = 50014; -- el saldo cambio, se debe reiniciar
            RETURN;
        END;

        BEGIN TRANSACTION tAplicaMovimiento;

            SET @flagEnTransaccion = 1;

            INSERT dbo.Comprobante (
                IdCuenta
                , Fecha
                , TextoEmail
            )
            SELECT @IdCuenta
                , @inFechaOperacion
                , @TextoEmail
            WHERE (@flagGeneraComprobante = 1);

            SET @IdComprobante = SCOPE_IDENTITY();  -- para vincular el FK, seria NULL si no hubiera comprobante

            INSERT dbo.Movimiento (
                IdEstadoCuenta
                , IdTipoMovimiento
                , IdComprobante
                , Fecha
                , Monto
                , Descripcion
                , NuevoSaldo
            )
            SELECT @IdEstadoCuenta
                , @IdTipoMovimiento
                , @IdComprobante
                , @inFechaOperacion
                , @inMonto
                , @inDescripcion
                , @NuevoSaldo;

            INSERT dbo.Movimiento (
                IdEstadoCuenta
                , IdTipoMovimiento
                , IdComprobante
                , Fecha
                , Monto
                , Descripcion
                , NuevoSaldo
            )
            SELECT @IdEstadoCuenta
                , @IDTIPOMOVCOMISIONSINPE
                , NULL -- la comision no genera comprobante
                , @inFechaOperacion
                , @ComisionSinpe
                , 'Comision por el exceso del limite diario del Sinpe'
                , @SaldoFinal
            WHERE (@flagCobraComisionSinpe = 1);

            UPDATE dbo.EstadoCuenta
            SET SaldoFinal = @SaldoFinal
                , SaldoMinimo = CASE
                                    WHEN (@SaldoFinal < SaldoMinimo) THEN @NuevoSaldo
                                    WHEN (@NuevoSaldo < SaldoMinimo) THEN @NuevoSaldo
                                    ELSE SaldoMinimo
                                END
                , CantOperacionesATM = CantOperacionesATM + @flagEsATM
                , CantOperacionesCajeroHumano = CantOperacionesCajeroHumano + @flagEsCajeroHumano
                , CantTransferenciasEntrantes = CantTransferenciasEntrantes + @flagEsSinpeEntrante
                , CantTransferenciasSalientes = CantTransferenciasSalientes + @flagEsSinpeSaliente
            WHERE Id = @IdEstadoCuenta;

            UPDATE dbo.Cuenta WITH (ROWLOCK)
            SET Saldo = @SaldoFinal
                , AcumuladosSinpe = @NuevoAcumuladoSinpe
                , FechaAcumuladosSinpe = @NuevaFechaAcumuladoSinpe
            WHERE Id = @IdCuenta;

        COMMIT TRANSACTION tAplicaMovimiento;

        SET @flagEnTransaccion = 0;
    END TRY
    BEGIN CATCH
        IF (@flagEnTransaccion = 1)
        BEGIN
            ROLLBACK TRANSACTION tAplicaMovimiento;
        END;

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

        SET @outResultCode = 50005;-- error de plataforma
    END CATCH;

    SET NOCOUNT OFF;
END;
GO