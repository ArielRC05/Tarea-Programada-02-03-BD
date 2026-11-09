USE TareaAhorros;
GO

-- Ejemplo de ejecucion:
-- DECLARE @outCode INT;
-- EXEC dbo.CargarCatalogos
--     @inXml = @xmlCatalogos
--     , @outResultCode = @outCode OUTPUT;

CREATE OR ALTER PROCEDURE dbo.CargarCatalogos
    @inXml XML
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @flagEnTransaccion BIT = 0;

    BEGIN TRY
        SET @outResultCode = 0;

        BEGIN TRANSACTION;
        
        SET @flagEnTransaccion = 1;
        -- 1. Tipo Documento Identidad
        INSERT dbo.TipoDocuIdentidad (
            Id
            , Nombre
        )
        SELECT
            tipo.Item.value('@Id', 'INT')
            , tipo.Item.value('@Nombre', 'VARCHAR(64)')
        FROM @inXml.nodes('//TipoDocuIdentidad') AS tipo(Item)
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.TipoDocuIdentidad AS docu
            WHERE (docu.Id = tipo.Item.value('@Id', 'INT'))
        );

        -- 2. Tipo Moneda
        INSERT dbo.TipoMoneda (
            Id
            , Nombre
            , Simbolo
        )
        SELECT
            tipo.Item.value('@Id', 'INT')
            , tipo.Item.value('@Nombre', 'VARCHAR(32)')
            , tipo.Item.value('@Simbolo', 'NVARCHAR(4)')
        FROM @inXml.nodes('//TipoMoneda') AS tipo(Item)
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.TipoMoneda AS moneda
            WHERE (moneda.Id = tipo.Item.value('@Id', 'INT'))
        );

        -- 3. Parentesco
        INSERT dbo.Parentesco (
            Id
            , Nombre
        )
        SELECT
            tipo.Item.value('@Id', 'INT')
            , tipo.Item.value('@Nombre', 'VARCHAR(32)')
        FROM @inXml.nodes('//Parentezco') AS tipo(Item)
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.Parentesco AS pariente
            WHERE (pariente.Id = tipo.Item.value('@Id', 'INT'))
        );

        -- 4. Tipo Cuenta Ahorro
        INSERT dbo.TipoCuentaAhorro (
            Id
            , IdTipoMoneda
            , Nombre
            , SaldoMinimo
            , MultaSaldoMin
            , CargoMensual
            , NumRetirosHumano
            , NumRetirosAutomatico
            , ComisionHumano
            , ComisionAutomatico
            , MontoMaxSinpeDiario
            , ComisionSinpe
            , TasaInteresAnual
        )
        SELECT
            tipo.Item.value('@Id', 'INT')
            , tipo.Item.value('@IdTipoMoneda', 'INT')
            , tipo.Item.value('@Nombre', 'VARCHAR(64)')
            , tipo.Item.value('@SaldoMinimo', 'DECIMAL(18,2)')
            , tipo.Item.value('@MultaSaldoMin', 'DECIMAL(18,2)')
            , ISNULL(tipo.Item.value('@CargoMensual', 'DECIMAL(18,2)'), ISNULL(tipo.Item.value('@CargoAnual', 'DECIMAL(18,2)'), 0.00))
            , tipo.Item.value('@NumRetirosHumano', 'INT')
            , tipo.Item.value('@NumRetirosAutomatico', 'INT')
            , ISNULL(tipo.Item.value('@ComisionHumano', 'DECIMAL(18,2)'), ISNULL(tipo.Item.value('@comisionHumano', 'DECIMAL(18,2)'), 0.00))
            , ISNULL(tipo.Item.value('@ComisionAutomatico', 'DECIMAL(18,2)'), ISNULL(tipo.Item.value('@comisionAutomatico', 'DECIMAL(18,2)'), 0.00))
            , ISNULL(tipo.Item.value('@MontoMaxSinpeDiario', 'DECIMAL(18,2)'), 100000.00)
            , ISNULL(tipo.Item.value('@ComisionSinpe', 'DECIMAL(18,2)'), 500.00)
            , ISNULL(tipo.Item.value('@TasaInteresAnual', 'DECIMAL(5,2)'), ISNULL(tipo.Item.value('@interes', 'DECIMAL(5,2)'), 0.00))
        FROM @inXml.nodes('//TipoCuentaAhorro') AS tipo(Item)
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.TipoCuentaAhorro AS cuenta
            WHERE (cuenta.Id = tipo.Item.value('@Id', 'INT'))
        );

        -- 5. Tipo Operacion (soporta @Id/@Nombre y @id/@nombre de TP2 y TP3)
        INSERT dbo.TipoOperacion (
            Id
            , Nombre
        )
        SELECT
            ISNULL(tipo.Item.value('@Id', 'INT'), tipo.Item.value('@id', 'INT'))
            , ISNULL(tipo.Item.value('@Nombre', 'VARCHAR(64)'), tipo.Item.value('@nombre', 'VARCHAR(64)'))
        FROM @inXml.nodes('//TipoOperacion') AS tipo(Item)
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.TipoOperacion AS operacion
            WHERE (operacion.Id = ISNULL(tipo.Item.value('@Id', 'INT'), tipo.Item.value('@id', 'INT')))
        );

        -- 6. Tipo Movimiento
        INSERT dbo.TipoMovimiento (
            Id
            , Nombre
            , flagEsCredito
            , flagGeneraComprobante
            , flagEsATM
            , flagEsCajeroHumano
            , flagEsSinpe
        )
        SELECT
            tipo.Item.value('@Id', 'INT')
            , tipo.Item.value('@Nombre', 'VARCHAR(64)')
            , CASE WHEN (tipo.Item.value('@Accion', 'VARCHAR(16)') = 'Credito') THEN 1 ELSE 0 END
            , ISNULL(tipo.Item.value('@flagGeneraComprobante', 'BIT'), 0)
            , CASE WHEN (tipo.Item.value('@Id', 'INT') IN (2, 4)) THEN 1 ELSE 0 END
            , CASE WHEN (tipo.Item.value('@Id', 'INT') IN (1, 5)) THEN 1 ELSE 0 END
            , CASE WHEN (tipo.Item.value('@Id', 'INT') IN (8, 9)) THEN 1 ELSE 0 END
        FROM @inXml.nodes('//TipoMovimiento') AS tipo(Item)
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.TipoMovimiento AS movimiento
            WHERE (movimiento.Id = tipo.Item.value('@Id', 'INT'))
        );

        COMMIT TRANSACTION;
        SET @flagEnTransaccion = 0;
    END TRY
    BEGIN CATCH
        IF (@flagEnTransaccion =1)
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