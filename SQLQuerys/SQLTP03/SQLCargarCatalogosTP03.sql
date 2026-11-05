USE TareaAhorros;
GO

--Ejemplo de ejecucion:
--DECLARE @resultCode INT;
--EXEC dbo.CargarCatalogos
--     @inXml = @xml
--     , @outResultCode = @resultCode OUTPUT;

ALTER PROCEDURE dbo.CargarCatalogos
    @inXml XML --parametro de entrada de tipo XML
    , @outResultCode INT OUTPUT --codigo del resultado
AS
BEGIN
    SET NOCOUNT ON; --evita mensajes de rows affected

    BEGIN TRY
        SET @outResultCode = 0;

        BEGIN TRANSACTION;

        INSERT dbo.TipoDocuIdentidad (
            Id
            , Nombre
        )
        SELECT tipo.Item.value('@Id', 'INT')
            , tipo.Item.value('@Nombre', 'VARCHAR(64)')
        FROM @inXml.nodes('//TipoDocuIdentidad') AS tipo(Item) --.nodes() convierte cada elemento del XML en una fila
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.TipoDocuIdentidad docu
            WHERE docu.Id = tipo.Item.value('@Id', 'INT')
        );

        INSERT dbo.TipoMoneda (
            Id
            , Nombre
            , Simbolo
        )
        SELECT tipo.Item.value('@Id', 'INT')
            , tipo.Item.value('@Nombre', 'VARCHAR(32)')
            , tipo.Item.value('@Simbolo', 'NVARCHAR(4)')
        FROM @inXml.nodes('//TipoMoneda') AS tipo(Item)
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.TipoMoneda moneda
            WHERE moneda.Id = tipo.Item.value('@Id', 'INT')
        );

        INSERT dbo.Parentesco (
            Id
            , Nombre
        )
        SELECT tipo.Item.value('@Id', 'INT')
            , tipo.Item.value('@Nombre', 'VARCHAR(32)')
        FROM @inXml.nodes('//Parentezco') AS tipo(Item)
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.Parentesco pariente
            WHERE pariente.Id = tipo.Item.value('@Id', 'INT')
        );

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
        SELECT tipo.Item.value('@Id', 'INT')
            , tipo.Item.value('@IdTipoMoneda', 'INT')
            , tipo.Item.value('@Nombre', 'VARCHAR(64)')
            , tipo.Item.value('@SaldoMinimo', 'DECIMAL(18,2)')
            , tipo.Item.value('@MultaSaldoMin', 'DECIMAL(18,2)')
            , tipo.Item.value('@CargoMensual', 'DECIMAL(18,2)')
            , tipo.Item.value('@NumRetirosHumano', 'INT')
            , tipo.Item.value('@NumRetirosAutomatico', 'INT')
            , tipo.Item.value('@ComisionHumano', 'DECIMAL(18,2)')
            , tipo.Item.value('@ComisionAutomatico', 'DECIMAL(18,2)')
            , tipo.Item.value('@MontoMaxSinpeDiario', 'DECIMAL(18,2)')
            , tipo.Item.value('@ComisionSinpe', 'DECIMAL(18,2)')
            , tipo.Item.value('@TasaInteresAnual', 'DECIMAL(5,2)')
        FROM @inXml.nodes('//TipoCuentaAhorro') AS tipo(Item)
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.TipoCuentaAhorro cuenta
            WHERE cuenta.Id = tipo.Item.value('@Id', 'INT')
        );

        INSERT dbo.TipoOperacion (
            Id
            , Nombre
        )
        SELECT tipo.Item.value('@Id', 'INT')
            , tipo.Item.value('@Nombre', 'VARCHAR(64)')
        FROM @inXml.nodes('//TipoOperacion') AS tipo(Item)
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.TipoOperacion operacion
            WHERE operacion.Id = tipo.Item.value('@Id', 'INT')
        );

        INSERT dbo.TipoMovimiento (
            Id
            , Nombre
            , flagEsCredito
            , flagGeneraComprobante
            , flagEsATM
            , flagEsCajeroHumano
            , flagEsSinpe
        )
        SELECT tipo.Item.value('@Id', 'INT')
            , tipo.Item.value('@Nombre', 'VARCHAR(64)')
            , CASE WHEN (tipo.Item.value('@Accion', 'VARCHAR(16)') = 'Credito') THEN 1 ELSE 0 END
            , tipo.Item.value('@flagGeneraComprobante', 'BIT')
            , CASE WHEN (tipo.Item.value('@Id', 'INT') IN (2, 4)) THEN 1 ELSE 0 END --alambrado: Deposito ATM y Retiro ATM
            , CASE WHEN (tipo.Item.value('@Id', 'INT') IN (1, 5)) THEN 1 ELSE 0 END --alambrado: Deposito y Retiro Ventana
            , CASE WHEN (tipo.Item.value('@Id', 'INT') IN (8, 9)) THEN 1 ELSE 0 END --alambrado: Deposito y Retiro Sinpe
        FROM @inXml.nodes('//TipoMovimiento') AS tipo(Item)
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.TipoMovimiento movimiento
            WHERE movimiento.Id = tipo.Item.value('@Id', 'INT')
        );

        COMMIT TRANSACTION; --guardar cambios
    END TRY
    BEGIN CATCH
        IF (@@TRANCOUNT > 0)
        BEGIN
            ROLLBACK TRANSACTION; --revertir cambios
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

        SET @outResultCode = 50001; --50001 es error de plataforma
    END CATCH;
END;
GO