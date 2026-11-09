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

    -- Tabla variable para iterar movimientos sin usar tablas temporales (#) ni cursores
    DECLARE @MovimientosDelDia TABLE (
        Secuencia INT IDENTITY(1,1) PRIMARY KEY
        , NumeroCuenta VARCHAR(32)
        , NombreTipoMovimiento VARCHAR(64)
        , Monto DECIMAL(18,2)
        , Descripcion VARCHAR(256)
    );

    BEGIN TRY
        SET @outResultCode = 0;

        -- 1. Pre-proceso y validaciones de control masivo antes de iterar
        SELECT
            @fechaInicio = MIN(F.Item.value('@Fecha', 'DATE'))
            , @fechaFin = MAX(F.Item.value('@Fecha', 'DATE'))
        FROM @inXml.nodes('//FechaOperacion') AS F(Item);

        -- Error 50202: la información preprocesada se ensució
        IF EXISTS (
            SELECT 1
            FROM dbo.EventLog AS el
            WHERE (el.IdTipoEvento = 1)
                AND (el.CantIdsProcesados < el.CantIdsPorProcesar)
        )
        BEGIN
            SET @outResultCode = 50202;
            RETURN;
        END;

        -- Error 50301: hay una fecha previa sin procesar
        SELECT
            @ultimaFechaCerrada = MAX(el.FechaEvento)
        FROM dbo.EventLog AS el
        WHERE (el.IdTipoEvento = 1);

        IF (@ultimaFechaCerrada IS NOT NULL AND @fechaInicio > DATEADD(DAY, 1, @ultimaFechaCerrada))
        BEGIN
            SET @outResultCode = 50301;
            RETURN;
        END;

        -- Error 50201: el proceso ya corrió para esa fecha
        IF EXISTS (
            SELECT 1
            FROM dbo.EventLog AS el
            WHERE (el.IdTipoEvento = 1)
                AND (el.FechaEvento >= @fechaInicio)
                AND (el.CantIdsProcesados = el.CantIdsPorProcesar)
        )
        BEGIN
            SET @outResultCode = 50201;
            RETURN;
        END;

        SET @fechaActual = @fechaInicio;

        -- 2. Recorrido diario consecutivo
        WHILE (@fechaActual IS NOT NULL AND @fechaActual <= @fechaFin)
        BEGIN
            SET @xmlDia = NULL;

            SELECT
                @xmlDia = F.Item.query('.')
            FROM @inXml.nodes('//FechaOperacion[@Fecha = sql:variable("@fechaActual")]') AS F(Item);

            -- Paso A: Cargar entidades y aplicar movimientos si el dia existe en el XML
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
                    @idxMov = MIN(mov.Secuencia)
                    , @maxMov = MAX(mov.Secuencia)
                FROM @MovimientosDelDia AS mov;

                WHILE (@idxMov IS NOT NULL AND @idxMov <= @maxMov)
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
                        , @outResultCode = @codigoSP OUTPUT;

                    IF (@codigoSP IN (50005, 50201, 50202, 50301))
                    BEGIN
                        SET @outResultCode = @codigoSP;
                        RETURN;
                    END;

                    SET @idxMov = @idxMov + 1;
                END;
            END;

            -- Paso B: Procesar cierres al final de cada fecha
            EXEC dbo.ProcesarCierresDelDia
                @inFechaOperacion = @fechaActual
                , @outResultCode = @codigoSP OUTPUT;

            IF (@codigoSP <> 0)
            BEGIN
                SET @outResultCode = @codigoSP;
                RETURN;
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