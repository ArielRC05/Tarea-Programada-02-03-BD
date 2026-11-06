USE TareaAhorros;
GO

CREATE OR ALTER PROCEDURE dbo.CargarEntidadesDelDia
    @inFechaOperacion DATE
    , @inXmlDia XML
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET @outResultCode = 0;

        BEGIN TRANSACTION;

        -- 1. Personas
        INSERT dbo.Persona (
            IdTipoDocuIdentidad
            , ValorDocumentoIdentidad
            , Nombre
            , FechaNacimiento
            , Email
        )
        SELECT
            per.Item.value('@TipoDocuIdentidad', 'INT')
            , per.Item.value('@ValorDocumentoIdentidad', 'VARCHAR(32)')
            , per.Item.value('@Nombre', 'VARCHAR(64)')
            , per.Item.value('@FechaNacimiento', 'DATE')
            , per.Item.value('@Email', 'VARCHAR(128)')
        FROM @inXmlDia.nodes('//Persona') AS per(Item)
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.Persona p
            WHERE p.ValorDocumentoIdentidad = per.Item.value('@ValorDocumentoIdentidad', 'VARCHAR(32)')
        );

        -- Teléfonos de las personas
        INSERT dbo.Telefono (
            IdPersona
            , Numero
        )
        SELECT
            p.Id
            , per.Item.value('@telefono1', 'VARCHAR(32)')
        FROM @inXmlDia.nodes('//Persona') AS per(Item)
        INNER JOIN dbo.Persona p
            ON p.ValorDocumentoIdentidad = per.Item.value('@ValorDocumentoIdentidad', 'VARCHAR(32)')
        WHERE per.Item.value('@telefono1', 'VARCHAR(32)') IS NOT NULL
            AND NOT EXISTS (
                SELECT 1
                FROM dbo.Telefono t
                WHERE t.IdPersona = p.Id
                    AND t.Numero = per.Item.value('@telefono1', 'VARCHAR(32)')
            );

        INSERT dbo.Telefono (
            IdPersona
            , Numero
        )
        SELECT
            p.Id
            , per.Item.value('@telefono2', 'VARCHAR(32)')
        FROM @inXmlDia.nodes('//Persona') AS per(Item)
        INNER JOIN dbo.Persona p
            ON p.ValorDocumentoIdentidad = per.Item.value('@ValorDocumentoIdentidad', 'VARCHAR(32)')
        WHERE per.Item.value('@telefono2', 'VARCHAR(32)') IS NOT NULL
            AND NOT EXISTS (
                SELECT 1
                FROM dbo.Telefono t
                WHERE t.IdPersona = p.Id
                    AND t.Numero = per.Item.value('@telefono2', 'VARCHAR(32)')
            );

        -- 2. Cuentas (CAhorrista + Cuenta con saldo en 0)
        INSERT dbo.CAhorrista (Id)
        SELECT DISTINCT p.Id
        FROM @inXmlDia.nodes('//Cuenta') AS cta(Item)
        INNER JOIN dbo.Persona p
            ON p.ValorDocumentoIdentidad = cta.Item.value('@ValorDocumentoIdentidadDelCliente', 'VARCHAR(32)')
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.CAhorrista ca
            WHERE ca.Id = p.Id
        );

        INSERT dbo.Cuenta (
            IdCAhorrista
            , IdTipoCuentaAhorro
            , NumeroCuenta
            , FechaCreacion
            , Saldo
        )
        SELECT
            p.Id
            , cta.Item.value('@TipoCuentaId', 'INT')
            , cta.Item.value('@NumeroCuenta', 'VARCHAR(32)')
            , @inFechaOperacion
            , 0.00
        FROM @inXmlDia.nodes('//Cuenta') AS cta(Item)
        INNER JOIN dbo.Persona p
            ON p.ValorDocumentoIdentidad = cta.Item.value('@ValorDocumentoIdentidadDelCliente', 'VARCHAR(32)')
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.Cuenta c
            WHERE c.NumeroCuenta = cta.Item.value('@NumeroCuenta', 'VARCHAR(32)')
        );

        -- 3. Beneficiarios (Beneficiario + BenefDeCA)
        INSERT dbo.Beneficiario (Id)
        SELECT DISTINCT p.Id
        FROM @inXmlDia.nodes('//Beneficiario') AS ben(Item)
        INNER JOIN dbo.Persona p
            ON p.ValorDocumentoIdentidad = ben.Item.value('@ValorDocumentoIdentidadBeneficiario', 'VARCHAR(32)')
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.Beneficiario b
            WHERE b.Id = p.Id
        );

        INSERT dbo.BenefDeCA (
            IdCuenta
            , IdBeneficiario
            , IdParentesco
            , Porcentaje
            , flagActivo
            , FechaDesactivacion
        )
        SELECT
            c.Id
            , p.Id
            , ben.Item.value('@IdParentezco', 'INT')
            , ben.Item.value('@Porcentaje', 'INT')
            , 1
            , NULL
        FROM @inXmlDia.nodes('//Beneficiario') AS ben(Item)
        INNER JOIN dbo.Cuenta c
            ON c.NumeroCuenta = ben.Item.value('@NumeroCuenta', 'VARCHAR(32)')
        INNER JOIN dbo.Persona p
            ON p.ValorDocumentoIdentidad = ben.Item.value('@ValorDocumentoIdentidadBeneficiario', 'VARCHAR(32)')
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.BenefDeCA bca
            WHERE bca.IdCuenta = c.Id
                AND bca.IdBeneficiario = p.Id
                AND bca.flagActivo = 1
        );

        COMMIT TRANSACTION;
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