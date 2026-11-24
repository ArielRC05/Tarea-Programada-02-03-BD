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

    BEGIN TRY
        DECLARE @flagEnTransaccion BIT = 0;

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
            , CASE
                  WHEN (tipo.Item.value('@CargoMensual', 'DECIMAL(18,2)') IS NOT NULL) THEN tipo.Item.value('@CargoMensual', 'DECIMAL(18,2)')
                  WHEN (tipo.Item.value('@CargoAnual', 'DECIMAL(18,2)') IS NOT NULL) THEN tipo.Item.value('@CargoAnual', 'DECIMAL(18,2)')
                  ELSE 0.00
              END
            , tipo.Item.value('@NumRetirosHumano', 'INT')
            , tipo.Item.value('@NumRetirosAutomatico', 'INT')
            , CASE
                  WHEN (tipo.Item.value('@ComisionHumano', 'DECIMAL(18,2)') IS NOT NULL) THEN tipo.Item.value('@ComisionHumano', 'DECIMAL(18,2)')
                  WHEN (tipo.Item.value('@comisionHumano', 'DECIMAL(18,2)') IS NOT NULL) THEN tipo.Item.value('@comisionHumano', 'DECIMAL(18,2)')
                  ELSE 0.00
              END
            , CASE
                  WHEN (tipo.Item.value('@ComisionAutomatico', 'DECIMAL(18,2)') IS NOT NULL) THEN tipo.Item.value('@ComisionAutomatico', 'DECIMAL(18,2)')
                  WHEN (tipo.Item.value('@comisionAutomatico', 'DECIMAL(18,2)') IS NOT NULL) THEN tipo.Item.value('@comisionAutomatico', 'DECIMAL(18,2)')
                  ELSE 0.00
              END
            , CASE
                  WHEN (tipo.Item.value('@MontoMaxSinpeDiario', 'DECIMAL(18,2)') IS NOT NULL) THEN tipo.Item.value('@MontoMaxSinpeDiario', 'DECIMAL(18,2)')
                  ELSE 100000.00
              END
            , CASE
                  WHEN (tipo.Item.value('@ComisionSinpe', 'DECIMAL(18,2)') IS NOT NULL) THEN tipo.Item.value('@ComisionSinpe', 'DECIMAL(18,2)')
                  ELSE 500.00
              END
            , CASE
                  WHEN (tipo.Item.value('@TasaInteresAnual', 'DECIMAL(5,2)') IS NOT NULL) THEN tipo.Item.value('@TasaInteresAnual', 'DECIMAL(5,2)')
                  WHEN (tipo.Item.value('@interes', 'DECIMAL(5,2)') IS NOT NULL) THEN tipo.Item.value('@interes', 'DECIMAL(5,2)')
                  ELSE 0.00
              END
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
            CASE
                WHEN (tipo.Item.value('@Id', 'INT') IS NOT NULL) THEN tipo.Item.value('@Id', 'INT')
                ELSE tipo.Item.value('@id', 'INT')
            END
            , CASE
                WHEN (tipo.Item.value('@Nombre', 'VARCHAR(64)') IS NOT NULL) THEN tipo.Item.value('@Nombre', 'VARCHAR(64)')
                ELSE tipo.Item.value('@nombre', 'VARCHAR(64)')
            END
        FROM @inXml.nodes('//TipoOperacion') AS tipo(Item)
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.TipoOperacion AS operacion
            WHERE (operacion.Id = CASE
                                      WHEN (tipo.Item.value('@Id', 'INT') IS NOT NULL) THEN tipo.Item.value('@Id', 'INT')
                                      ELSE tipo.Item.value('@id', 'INT')
                                  END)
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
            , CASE
                  WHEN (tipo.Item.value('@flagGeneraComprobante', 'BIT') IS NOT NULL) THEN tipo.Item.value('@flagGeneraComprobante', 'BIT')
                  ELSE 0
              END
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
        IF (@flagEnTransaccion = 1)
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

    SET NOCOUNT OFF;
END;
GO