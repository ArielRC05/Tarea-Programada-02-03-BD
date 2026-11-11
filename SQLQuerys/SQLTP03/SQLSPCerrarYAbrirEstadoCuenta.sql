USE TareaAhorros
GO

--Ejemplo de ejecucion:
--DECLARE @r INT;
--EXEC dbo.CerrarYAbrirEstadoCuenta
--    @inIdEstadoCuenta = 1
--    , @inFechaOperacion = '2026-04-01'
--    , @inIdEventLog = 1
--    , @outResultCode = @r OUTPUT;
--SELECT @r AS outResultCode;

CREATE OR ALTER PROCEDURE dbo.CerrarYAbrirEstadoCuenta
    @inIdEstadoCuenta INT
    , @inFechaOperacion DATE
    , @inIdEventLog INT
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET @outResultCode = 0;

        DECLARE @IdCuenta INT
            , @FechaCreacion DATE
            , @SaldoCuenta DECIMAL(18,2)
            , @FechaFinEstado DATE
            , @SaldoMinimoEstado DECIMAL(18,2)
            , @CantATM INT
            , @CantCajeroHumano INT
            , @TasaInteresAnual DECIMAL(5,2)
            , @SaldoMinimoTipo DECIMAL(18,2)
            , @MultaSaldoMin DECIMAL(18,2)
            , @CargoMensual DECIMAL(18,2)
            , @NumRetirosHumano INT
            , @NumRetirosAutomatico INT
            , @ComisionHumano DECIMAL(18,2)
            , @ComisionAutomatico DECIMAL(18,2)
            , @MontoIntereses DECIMAL(18,2)
            , @MontoExcesoATM DECIMAL(18,2)
            , @MontoExcesoHumano DECIMAL(18,2)
            , @MontoMultaSaldoMin DECIMAL(18,2)
            , @SaldoTrasIntereses DECIMAL(18,2)
            , @SaldoTrasExcesoATM DECIMAL(18,2)
            , @SaldoTrasExcesoHumano DECIMAL(18,2)
            , @SaldoTrasMultaSaldoMin DECIMAL(18,2)
            , @SaldoCierre DECIMAL(18,2)
            , @NuevaFechaInicio DATE
            , @NuevaFechaFin DATE
            , @flagEnTransaccion BIT = 0
            --Valores alambrados 
            , @IDTIPOMOVEXCESOHUMANO INT = 6 --Comision exceso ventana
            , @IDTIPOMOVEXCESOATM INT = 7 --Comision exceso ATM
            , @IDTIPOMOVCARGOMENSUAL INT = 11 --Cargo por servicio mensual
            , @IDTIPOMOVINTERESES INT = 12 --Intereses mensuales
            , @IDTIPOMOVMULTASALDOMIN INT = 16; --Multa saldo minimo

        DECLARE @MovimientosCierre TABLE (
            Sec INT IDENTITY(1,1)
            , IdTipoMovimiento INT
            , Monto DECIMAL(18,2)
            , Descripcion VARCHAR(256)
            , NuevoSaldo DECIMAL(18,2)
        );

        --Los precalculos y lecturas
        SELECT @IdCuenta = E.IdCuenta
            , @FechaFinEstado = E.FechaFin
            , @SaldoMinimoEstado = E.SaldoMinimo
            , @CantATM = E.CantOperacionesATM
            , @CantCajeroHumano = E.CantOperacionesCajeroHumano
            , @FechaCreacion = C.FechaCreacion
            , @SaldoCuenta = C.Saldo
            , @TasaInteresAnual = T.TasaInteresAnual
            , @SaldoMinimoTipo = T.SaldoMinimo
            , @MultaSaldoMin = T.MultaSaldoMin
            , @CargoMensual = T.CargoMensual
            , @NumRetirosHumano = T.NumRetirosHumano
            , @NumRetirosAutomatico = T.NumRetirosAutomatico
            , @ComisionHumano = T.ComisionHumano
            , @ComisionAutomatico = T.ComisionAutomatico
        FROM dbo.EstadoCuenta E
        INNER JOIN dbo.Cuenta C
            ON C.Id = E.IdCuenta
        INNER JOIN dbo.TipoCuentaAhorro T
            ON T.Id = C.IdTipoCuentaAhorro
        WHERE E.Id = @inIdEstadoCuenta;

        IF (@IdCuenta IS NULL)
        BEGIN
            SET @outResultCode = 50021;-- el estado de cuenta no existe
            RETURN;
        END;

        IF (@FechaFinEstado <> @inFechaOperacion)
        BEGIN
            SET @outResultCode = 50022;-- el estado de cuenta no vence en la fecha de operacion
            RETURN;
        END;

        IF EXISTS (
            SELECT 1
            FROM dbo.EstadoCuenta E
            WHERE (E.IdCuenta = @IdCuenta)
                AND (E.FechaInicio > @FechaFinEstado)
        )
        BEGIN
            SET @outResultCode = 50023;-- el estado de cuenta ya fue cerrado
            RETURN;
        END;

        -- Fechas del estado de cuenta nuevo, junto con la fecha de creacion
        SET @NuevaFechaInicio = DATEADD(DAY, 1, @FechaFinEstado);
        SET @NuevaFechaFin = DATEADD(MONTH, DATEDIFF(MONTH, @FechaCreacion, @FechaFinEstado) + 1, @FechaCreacion);

        -- Montos del cierre, 0 si no aplica
        SET @MontoIntereses = CASE
                                WHEN (@SaldoMinimoEstado > 0) THEN (@SaldoMinimoEstado * @TasaInteresAnual / 100) / 12
                                ELSE 0
                              END;

        SET @MontoExcesoATM = CASE
                                WHEN (@CantATM > @NumRetirosAutomatico) THEN (@CantATM - @NumRetirosAutomatico) * @ComisionAutomatico
                                ELSE 0
                              END;

        SET @MontoExcesoHumano = CASE
                                    WHEN (@CantCajeroHumano > @NumRetirosHumano) THEN (@CantCajeroHumano - @NumRetirosHumano) * @ComisionHumano
                                    ELSE 0
                                 END;

        SET @MontoMultaSaldoMin = CASE
                                    WHEN (@SaldoMinimoEstado < @SaldoMinimoTipo) THEN @MultaSaldoMin
                                    ELSE 0
                                  END;

        -- Saldo corrido despues de cada movimiento
        SET @SaldoTrasIntereses = @SaldoCuenta + @MontoIntereses;
        SET @SaldoTrasExcesoATM = @SaldoTrasIntereses - @MontoExcesoATM;
        SET @SaldoTrasExcesoHumano = @SaldoTrasExcesoATM - @MontoExcesoHumano;
        SET @SaldoTrasMultaSaldoMin = @SaldoTrasExcesoHumano - @MontoMultaSaldoMin;
        SET @SaldoCierre = @SaldoTrasMultaSaldoMin - @CargoMensual;

        INSERT @MovimientosCierre (IdTipoMovimiento, Monto, Descripcion, NuevoSaldo)
        SELECT @IDTIPOMOVINTERESES, @MontoIntereses, 'Intereses mensuales', @SaldoTrasIntereses;

        INSERT @MovimientosCierre (IdTipoMovimiento, Monto, Descripcion, NuevoSaldo)
        SELECT @IDTIPOMOVEXCESOATM, @MontoExcesoATM, 'Comision por exceso de operaciones en cajero automatico', @SaldoTrasExcesoATM;

        INSERT @MovimientosCierre (IdTipoMovimiento, Monto, Descripcion, NuevoSaldo)
        SELECT @IDTIPOMOVEXCESOHUMANO, @MontoExcesoHumano, 'Comision por exceso de operaciones en cajero humano', @SaldoTrasExcesoHumano;

        INSERT @MovimientosCierre (IdTipoMovimiento, Monto, Descripcion, NuevoSaldo)
        SELECT @IDTIPOMOVMULTASALDOMIN, @MontoMultaSaldoMin, 'Multa por saldo minimo incumplido', @SaldoTrasMultaSaldoMin;

        INSERT @MovimientosCierre (IdTipoMovimiento, Monto, Descripcion, NuevoSaldo)
        SELECT @IDTIPOMOVCARGOMENSUAL, @CargoMensual, 'Cargo mensual por servicios', @SaldoCierre;

        --Comprobar que no se ensucio
        IF EXISTS (
            SELECT 1
            FROM dbo.Cuenta C
            WHERE (C.Id = @IdCuenta)
                AND (C.Saldo <> @SaldoCuenta)
        )
        BEGIN
            SET @outResultCode = 50014; --el saldo cambio, se debe reiniciar
            RETURN;
        END;

        BEGIN TRANSACTION tCierraYAbreEstado;

            SET @flagEnTransaccion = 1;

            -- Movimientos del cierre en el estado que se cierra (monto mayor a 0)
            INSERT dbo.Movimiento ( 
                IdEstadoCuenta
                , IdTipoMovimiento
                , IdComprobante
                , Fecha
                , Monto
                , Descripcion
                , NuevoSaldo
            )
            SELECT @inIdEstadoCuenta
                , M.IdTipoMovimiento
                , NULL -- ninguno de estos movimientos genera comprobante
                , @inFechaOperacion
                , M.Monto
                , M.Descripcion
                , M.NuevoSaldo
            FROM @MovimientosCierre M
            WHERE (M.Monto > 0)
            ORDER BY M.Sec;

            -- Cerrar estado de cuenta
            UPDATE dbo.EstadoCuenta
            SET SaldoFinal = @SaldoCierre
            WHERE Id = @inIdEstadoCuenta;

            --Esstado de cuenta siguiente
            INSERT dbo.EstadoCuenta (
                IdCuenta
                , FechaInicio
                , FechaFin
                , SaldoInicial
                , SaldoFinal
                , SaldoMinimo
                , CantTransferenciasEntrantes
                , CantTransferenciasSalientes
                , CantOperacionesATM
                , CantOperacionesCajeroHumano
            )
            SELECT @IdCuenta
                , @NuevaFechaInicio
                , @NuevaFechaFin
                , @SaldoCierre
                , @SaldoCierre
                , @SaldoCierre
                , 0
                , 0
                , 0
                , 0;
                 
            --Avance del proceso masivo junto con el cierre de esta cuenta
            UPDATE dbo.EventLog WITH (ROWLOCK)
            SET UltimoIdProcesado = @inIdEstadoCuenta
                , CantIdsProcesados = CantIdsProcesados + 1
            WHERE Id = @inIdEventLog;

            UPDATE dbo.Cuenta WITH (ROWLOCK) --saldo actualizado de ultimo
            SET Saldo = @SaldoCierre
            WHERE Id = @IdCuenta;

        COMMIT TRANSACTION tCierraYAbreEstado;

        SET @flagEnTransaccion = 0;
    END TRY
    BEGIN CATCH
        IF (@flagEnTransaccion = 1)
        BEGIN
            ROLLBACK TRANSACTION tCierraYAbreEstado; 
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