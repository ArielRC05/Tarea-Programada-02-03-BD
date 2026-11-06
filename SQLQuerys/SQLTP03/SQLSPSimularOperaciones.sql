USE TareaAhorros;
GO

CREATE OR ALTER PROCEDURE dbo.SimularOperaciones
    @inXml XML
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @fechaInicio DATE;
    DECLARE @fechaFin DATE;
    DECLARE @fechaActual DATE;
    DECLARE @ultimaFechaCerrada DATE;
    DECLARE @xmlDia XML;
    DECLARE @codigoSP INT;

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

    BEGIN TRY
        SET @outResultCode = 0;

        -- Obtener primera y última fecha del XML (soporta FechaOperacion o Fecha_Operacion)
        SELECT
            @fechaInicio = MIN(F.Item.value('@Fecha', 'DATE'))
            , @fechaFin = MAX(F.Item.value('@Fecha', 'DATE'))
        FROM @inXml.nodes('//FechaOperacion | //Fecha_Operacion') AS F(Item);

        -- Verificar en EventLog si la información preprocesada quedó sucia/incompleta (50202)
        IF EXISTS (
            SELECT 1
            FROM dbo.EventLog el
            WHERE el.IdTipoEvento = 1
                AND el.CantIdsProcesados < el.CantIdsPorProcesar
        )
        BEGIN
            SET @outResultCode = 50202;
            RETURN;
        END;

        -- Verificar si ya hubo fechas procesadas previamente para no brincar días (50301)
        SELECT @ultimaFechaCerrada = MAX(el.FechaEvento)
        FROM dbo.EventLog el
        WHERE el.IdTipoEvento = 1;

        IF (@ultimaFechaCerrada IS NOT NULL AND @fechaInicio > DATEADD(DAY, 1, @ultimaFechaCerrada))
        BEGIN
            SET @outResultCode = 50301;
            RETURN;
        END;

        SET @fechaActual = @fechaInicio;

        -- Ciclo diario consecutivo desde la primera hasta la última fecha
        WHILE (@fechaActual IS NOT NULL AND @fechaActual <= @fechaFin)
        BEGIN
            -- Extraer el sub-árbol XML de la fecha actual (si existe en el XML)
            SET @xmlDia = NULL;

            SELECT @xmlDia = F.Item.query('.')
            FROM @inXml.nodes('//FechaOperacion[@Fecha = sql:variable("@fechaActual")] | //Fecha_Operacion[@Fecha = sql:variable("@fechaActual")]') AS F(Item);

            -- 1. Si hay nodo XML para esta fecha, cargar entidades y movimientos
            IF (@xmlDia IS NOT NULL AND CONVERT(NVARCHAR(MAX), @xmlDia) <> '')
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

                -- Extraer los movimientos de ese día en el orden del XML
                DELETE FROM @MovimientosDelDia;

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

                SELECT
                    @idxMov = MIN(Secuencia)
                    , @maxMov = MAX(Secuencia)
                FROM @MovimientosDelDia;

                -- 2. Llamar a dbo.AplicarMovimiento una vez por cada nodo <Movimientos>
                WHILE (@idxMov IS NOT NULL AND @idxMov <= @maxMov)
                BEGIN
                    SELECT
                        @numeroCuenta = NumeroCuenta
                        , @nombreTipoMov = NombreTipoMovimiento
                        , @monto = Monto
                        , @descripcion = Descripcion
                    FROM @MovimientosDelDia
                    WHERE Secuencia = @idxMov;

                    EXEC dbo.AplicarMovimiento
                        @inFechaOperacion = @fechaActual
                        , @inNumeroCuenta = @numeroCuenta
                        , @inNombreTipoMovimiento = @nombreTipoMov
                        , @inMonto = @monto
                        , @inDescripcion = @descripcion
                        , @outResultCode = @codigoSP OUTPUT;

                    -- Si ocurre un error estructural/control (50005, 50201, 50202, 50301), detener simulación
                    IF (@codigoSP IN (50005, 50201, 50202, 50301))
                    BEGIN
                        SET @outResultCode = @codigoSP;
                        RETURN;
                    END;

                    SET @idxMov = @idxMov + 1;
                END;
            END;

            -- 3. Al final de cada fecha, ejecutar ProcesarCierresDelDia
            EXEC dbo.ProcesarCierresDelDia
                @inFechaOperacion = @fechaActual
                , @outResultCode = @codigoSP OUTPUT;

            IF (@codigoSP <> 0)
            BEGIN
                SET @outResultCode = @codigoSP;
                RETURN;
            END;

            -- Avanzar al día siguiente
            SET @fechaActual = DATEADD(DAY, 1, @fechaActual);
        END;
    END TRY
    BEGIN CATCH
        IF (@@TRANCOUNT > 0)
        BEGIN
            ROLLBACK TRANSACTION;
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

        SET @outResultCode = 50005;
    END CATCH;
END;
GO