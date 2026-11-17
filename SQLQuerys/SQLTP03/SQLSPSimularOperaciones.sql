USE TareaAhorros;
GO

-- Ejemplo de ejecucion:
-- DECLARE @outCode INT;
-- EXEC dbo.SimularOperaciones
--     @inXml = @xmlOperaciones
--     , @outResultCode = @outCode OUTPUT;

CREATE OR ALTER PROCEDURE dbo.SimularOperaciones
    @inXml XML
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET @outResultCode = 0;

        DECLARE @fechaInicio DATE;
        DECLARE @fechaFin DATE;
        DECLARE @fechaActual DATE;
        DECLARE @ultimaFechaCerrada DATE;
        DECLARE @xmlDia XML;
        DECLARE @codigoSP INT;
        DECLARE @IDEVENTOCIERRE INT = 1;
        DECLARE @IDEVENTOMOVIMIENTOS INT = 2;
        DECLARE @currentEventLogId INT;
        DECLARE @ultimoIdProcesado INT;
        DECLARE @cantMovimientosDia INT;

        DECLARE @idxMov INT;
        DECLARE @maxMov INT;
        DECLARE @numeroCuenta VARCHAR(32);
        DECLARE @nombreTipoMov VARCHAR(64);
        DECLARE @monto DECIMAL(18,2);
        DECLARE @descripcion VARCHAR(256);

        DECLARE @MovimientosDelDia TABLE (
            Secuencia INT IDENTITY(1,1) PRIMARY KEY
            , NumeroCuenta VARCHAR(32)
            , NombreTipoMovimiento VARCHAR(64)
            , Monto DECIMAL(18,2)
            , Descripcion VARCHAR(256)
        );

        -- 1. Obtener primera y ultima fecha del XML
        SELECT
            @fechaInicio = MIN(F.Item.value('@Fecha', 'DATE'))
            , @fechaFin = MAX(F.Item.value('@Fecha', 'DATE'))
        FROM @inXml.nodes('//FechaOperacion') AS F(Item);

        -- Error 50202: existe un proceso incompleto fuera del rango actual
        IF EXISTS (
            SELECT 1
            FROM dbo.EventLog AS el
            WHERE (el.IdTipoEvento IN (@IDEVENTOCIERRE, @IDEVENTOMOVIMIENTOS))
                AND (el.CantIdsProcesados < el.CantIdsPorProcesar)
                AND (
                    (el.FechaEvento < @fechaInicio)
                    OR (el.FechaEvento > @fechaFin)
                )
        )
        BEGIN
            SET @outResultCode = 50202;
            RETURN;
        END;

        -- Determinar ultima fecha cerrada completamente
        SELECT
            @ultimaFechaCerrada = MAX(el.FechaEvento)
        FROM dbo.EventLog AS el
        WHERE (el.IdTipoEvento = @IDEVENTOCIERRE)
            AND (el.CantIdsProcesados = el.CantIdsPorProcesar);

        -- Error 50201: el rango completo ya corrio sin pendientes
        IF (@ultimaFechaCerrada IS NOT NULL)
            AND (@ultimaFechaCerrada >= @fechaFin)
            AND NOT EXISTS (
                SELECT 1
                FROM dbo.EventLog AS el
                WHERE (el.IdTipoEvento IN (@IDEVENTOCIERRE, @IDEVENTOMOVIMIENTOS))
                    AND (el.CantIdsProcesados < el.CantIdsPorProcesar)
            )
        BEGIN
            SET @outResultCode = 50201;
            RETURN;
        END;

        --si se brinco una fecha, procesar primero desde el dia siguiente a la ultima fecha cerrada
        SET @fechaActual = CASE
                               WHEN (@ultimaFechaCerrada IS NOT NULL)
                                    AND (@fechaInicio > DATEADD(DAY, 1, @ultimaFechaCerrada))
                                   THEN DATEADD(DAY, 1, @ultimaFechaCerrada)
                               ELSE @fechaInicio
                           END;

        -- 2. Recorrido diario consecutivo
        WHILE (@fechaActual IS NOT NULL)
            AND (@fechaActual <= @fechaFin)
        BEGIN
            -- Paso A: Cargar entidades y aplicar movimientos si el dia aun no completo movimientos
            IF NOT EXISTS (
                SELECT 1
                FROM dbo.EventLog AS el
                WHERE (el.IdTipoEvento = @IDEVENTOMOVIMIENTOS)
                    AND (el.FechaEvento = @fechaActual)
                    AND (el.CantIdsPorProcesar = el.CantIdsProcesados)
            )
            BEGIN
                SET @currentEventLogId = 0;
                SET @ultimoIdProcesado = 0;
                SET @cantMovimientosDia = 0;
                SET @xmlDia = NULL;

                SELECT
                    @currentEventLogId = el.Id
                    , @ultimoIdProcesado = el.UltimoIdProcesado
                FROM dbo.EventLog AS el
                WHERE (el.IdTipoEvento = @IDEVENTOMOVIMIENTOS)
                    AND (el.FechaEvento = @fechaActual);

                SELECT
                    @xmlDia = F.Item.query('.')
                FROM @inXml.nodes('//FechaOperacion[@Fecha = sql:variable("@fechaActual")]') AS F(Item);

                DELETE FROM @MovimientosDelDia;

                IF (@xmlDia IS NOT NULL)
                    AND (CONVERT(NVARCHAR(MAX), @xmlDia) <> '')
                BEGIN
                    EXEC dbo.CargarEntidadesDelDia
                        @inFechaOperacion = @fechaActual
                        , @inXmlDia = @xmlDia
                        , @outResultCode = @codigoSP OUTPUT;

                    IF (@codigoSP <> 0)
                    BEGIN
                        SET @outResultCode = @codigoSP;
                        RETURN;
                    END;

                    INSERT INTO @MovimientosDelDia (
                        NumeroCuenta
                        , NombreTipoMovimiento
                        , Monto
                        , Descripcion
                    )
                    SELECT
                        LTRIM(RTRIM(M.Item.value('@CodigoCuenta', 'VARCHAR(32)')))
                        , LTRIM(RTRIM(M.Item.value('@Tipo', 'VARCHAR(64)')))
                        , M.Item.value('@Monto', 'DECIMAL(18,2)')
                        , M.Item.value('@Descripcion', 'VARCHAR(256)')
                    FROM @xmlDia.nodes('//Movimientos') AS M(Item);

                    SET @cantMovimientosDia = @@ROWCOUNT;
                END;

                INSERT dbo.EventLog (
                    IdTipoEvento
                    , FechaEvento
                    , Descripcion
                    , CantIdsPorProcesar
                    , UltimoIdProcesado
                    , CantIdsProcesados
                )
                SELECT
                    @IDEVENTOMOVIMIENTOS
                    , @fechaActual
                    , 'Movimientos del dia'
                    , @cantMovimientosDia
                    , 0
                    , 0
                WHERE (@currentEventLogId = 0);

                SET @currentEventLogId = CASE
                                             WHEN (@currentEventLogId = 0) THEN SCOPE_IDENTITY()
                                             ELSE @currentEventLogId
                                         END;

                SET @idxMov = @ultimoIdProcesado + 1;

                SELECT
                    @maxMov = MAX(mov.Secuencia)
                FROM @MovimientosDelDia AS mov;

                WHILE (@idxMov IS NOT NULL)
                    AND (@maxMov IS NOT NULL)
                    AND (@idxMov <= @maxMov)
                BEGIN
                    SELECT
                        @numeroCuenta = mov.NumeroCuenta
                        , @nombreTipoMov = mov.NombreTipoMovimiento
                        , @monto = mov.Monto
                        , @descripcion = mov.Descripcion
                    FROM @MovimientosDelDia AS mov
                    WHERE (mov.Secuencia = @idxMov);

                    EXEC dbo.AplicarMovimiento
                        @inFechaOperacion = @fechaActual
                        , @inNumeroCuenta = @numeroCuenta
                        , @inNombreTipoMovimiento = @nombreTipoMov
                        , @inMonto = @monto
                        , @inDescripcion = @descripcion
                        , @inIdEventLog = @currentEventLogId
                        , @inSecuenciaMov = @idxMov
                        , @outResultCode = @codigoSP OUTPUT;

                    IF (@codigoSP <> 0)
                    BEGIN
                        SET @outResultCode = @codigoSP;
                        RETURN;
                    END;

                    SET @idxMov = @idxMov + 1;
                END;
            END;

            -- Paso B: Procesar cierres al final de cada fecha si aun no completo
            IF NOT EXISTS (
                SELECT 1
                FROM dbo.EventLog AS el
                WHERE (el.IdTipoEvento = @IDEVENTOCIERRE)
                    AND (el.FechaEvento = @fechaActual)
                    AND (el.CantIdsPorProcesar = el.CantIdsProcesados)
            )
            BEGIN
                EXEC dbo.ProcesarCierresDelDia
                    @inFechaOperacion = @fechaActual
                    , @outResultCode = @codigoSP OUTPUT;

                IF (@codigoSP <> 0)
                BEGIN
                    SET @outResultCode = @codigoSP;
                    RETURN;
                END;
            END;

            SET @fechaActual = DATEADD(DAY, 1, @fechaActual);
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