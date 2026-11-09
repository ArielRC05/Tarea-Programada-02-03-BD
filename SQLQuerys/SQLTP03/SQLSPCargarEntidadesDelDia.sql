USE TareaAhorros;
GO

-- Ejemplo de ejecucion:
-- DECLARE @outCode INT;
-- EXEC dbo.CargarEntidadesDelDia
--     @inFechaOperacion = '2026-03-01'
--     , @inXmlDia = @xmlDia
--     , @outResultCode = @outCode OUTPUT;

CREATE OR ALTER PROCEDURE dbo.CargarEntidadesDelDia
    @inFechaOperacion DATE
    , @inXmlDia XML
    , @outResultCode INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @flagEnTransaccion BIT = 0;

    BEGIN TRY
        SET @outResultCode = 0;

        BEGIN TRANSACTION;
        SET @flagEnTransaccion = 1;

        -- 1. Insertar Personas del dia
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
            FROM dbo.Persona AS p
            WHERE (p.ValorDocumentoIdentidad = per.Item.value('@ValorDocumentoIdentidad', 'VARCHAR(32)'))
        );

        -- 2. Insertar Telefonos
        INSERT dbo.Telefono (
            IdPersona
            , Numero
        )
        SELECT
            p.Id
            , per.Item.value('@telefono1', 'VARCHAR(32)')
        FROM @inXmlDia.nodes('//Persona') AS per(Item)
        INNER JOIN dbo.Persona AS p
            ON (p.ValorDocumentoIdentidad = per.Item.value('@ValorDocumentoIdentidad', 'VARCHAR(32)'))
        WHERE (per.Item.value('@telefono1', 'VARCHAR(32)') IS NOT NULL)
            AND NOT EXISTS (
                SELECT 1
                FROM dbo.Telefono AS t
                WHERE (t.IdPersona = p.Id)
                    AND (t.Numero = per.Item.value('@telefono1', 'VARCHAR(32)'))
            );

        INSERT dbo.Telefono (
            IdPersona
            , Numero
        )
        SELECT
            p.Id
            , per.Item.value('@telefono2', 'VARCHAR(32)')
        FROM @inXmlDia.nodes('//Persona') AS per(Item)
        INNER JOIN dbo.Persona AS p
            ON (p.ValorDocumentoIdentidad = per.Item.value('@ValorDocumentoIdentidad', 'VARCHAR(32)'))
        WHERE (per.Item.value('@telefono2', 'VARCHAR(32)') IS NOT NULL)
            AND NOT EXISTS (
                SELECT 1
                FROM dbo.Telefono AS t
                WHERE (t.IdPersona = p.Id)
                    AND (t.Numero = per.Item.value('@telefono2', 'VARCHAR(32)'))
            );

        -- 3. Registrar CAhorrista para duenos de cuentas
        INSERT dbo.CAhorrista (
            Id
        )
        SELECT
            p.Id
        FROM dbo.Persona AS p
        WHERE EXISTS (
                SELECT 1
                FROM @inXmlDia.nodes('//Cuenta') AS cta(Item)
                WHERE (cta.Item.value('@ValorDocumentoIdentidadDelCliente', 'VARCHAR(32)') = p.ValorDocumentoIdentidad)
            )
            AND NOT EXISTS (
                SELECT 1
                FROM dbo.CAhorrista AS ca
                WHERE (ca.Id = p.Id)
            );

        -- 4. Insertar Cuentas (saldo inicial en 0.00, el trigger abre el primer estado de cuenta)
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
        INNER JOIN dbo.Persona AS p
            ON (p.ValorDocumentoIdentidad = cta.Item.value('@ValorDocumentoIdentidadDelCliente', 'VARCHAR(32)'))
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.Cuenta AS c
            WHERE (c.NumeroCuenta = cta.Item.value('@NumeroCuenta', 'VARCHAR(32)'))
        );

        -- 5. Registrar Beneficiarios
        INSERT dbo.Beneficiario (
            Id
        )
        SELECT
            p.Id
        FROM dbo.Persona AS p
        WHERE EXISTS (
                SELECT 1
                FROM @inXmlDia.nodes('//Beneficiario') AS ben(Item)
                WHERE (ben.Item.value('@ValorDocumentoIdentidadBeneficiario', 'VARCHAR(32)') = p.ValorDocumentoIdentidad)
            )
            AND NOT EXISTS (
                SELECT 1
                FROM dbo.Beneficiario AS b
                WHERE (b.Id = p.Id)
            );

        -- 6. Insertar relacion BenefDeCA
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
        INNER JOIN dbo.Cuenta AS c
            ON (c.NumeroCuenta = ben.Item.value('@NumeroCuenta', 'VARCHAR(32)'))
        INNER JOIN dbo.Persona AS p
            ON (p.ValorDocumentoIdentidad = ben.Item.value('@ValorDocumentoIdentidadBeneficiario', 'VARCHAR(32)'))
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.BenefDeCA AS bca
            WHERE (bca.IdCuenta = c.Id)
                AND (bca.IdBeneficiario = p.Id)
                AND (bca.flagActivo = 1)
        );

        -- 7. Insertar Usuarios (se vinculan a su Persona por ValorDocId)
        INSERT dbo.Usuario (
            IdPersona
            , NombreUsuario
            , Contrasena
            , flagEsAdministrador
        )
        SELECT
            p.Id
            , usu.Item.value('@User', 'VARCHAR(64)')
            , usu.Item.value('@Pass', 'VARCHAR(64)')
            , usu.Item.value('@EsAdministrador', 'BIT')
        FROM @inXmlDia.nodes('//Usuario') AS usu(Item)
        INNER JOIN dbo.Persona AS p
            ON (p.ValorDocumentoIdentidad = usu.Item.value('@ValorDocId', 'VARCHAR(32)'))
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.Usuario AS u
            WHERE (u.NombreUsuario = usu.Item.value('@User', 'VARCHAR(64)'))
        );

        -- 8. Insertar UsuarioPuedeVer (usuario y cuenta ya existen en este punto)
        INSERT dbo.UsuarioPuedeVer (
            IdUsuario
            , IdCuenta
        )
        SELECT
            u.Id
            , c.Id
        FROM @inXmlDia.nodes('//UsuarioPuedeVer') AS pv(Item)
        INNER JOIN dbo.Usuario AS u
            ON (u.NombreUsuario = pv.Item.value('@User', 'VARCHAR(64)'))
        INNER JOIN dbo.Cuenta AS c
            ON (c.NumeroCuenta = pv.Item.value('@NumeroCuenta', 'VARCHAR(32)'))
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.UsuarioPuedeVer AS upv
            WHERE (upv.IdUsuario = u.Id)
                AND (upv.IdCuenta = c.Id)
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
END;
GO