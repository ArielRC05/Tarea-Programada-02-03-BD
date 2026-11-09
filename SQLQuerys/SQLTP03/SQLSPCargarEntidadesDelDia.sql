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

    DECLARE @CuentasNuevas TABLE (
        Secuencia INT IDENTITY(1,1) PRIMARY KEY
        , IdCAhorrista INT
        , IdTipoCuentaAhorro INT
        , NumeroCuenta VARCHAR(32)
        , FechaCreacion DATE
        , Saldo DECIMAL(18,2)
    );

    DECLARE @idx INT;
    DECLARE @maxIdx INT;

    BEGIN TRY
        SET @outResultCode = 0;

        IF (@inXmlDia IS NULL)
        BEGIN
            RETURN;
        END;

        BEGIN TRANSACTION;
        SET @flagEnTransaccion = 1;

        -- 1. Insertar Personas nuevas del dia
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

        -- 2. Insertar Telefono 1 y Telefono 2 de las personas
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

        -- 3. Registrar en CAhorrista a los duenos de cuentas nuevas
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

        -- 4. Preparar e insertar Cuentas del dia (dispara el Trigger de apertura de EstadoCuenta)
        INSERT INTO @CuentasNuevas (
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
            , ISNULL(@inFechaOperacion, ISNULL(cta.Item.value('@FechaCreacion', 'DATE'), CONVERT(DATE, GETDATE())))
            , ISNULL(cta.Item.value('@Saldo', 'DECIMAL(18,2)'), 0.00)
        FROM @inXmlDia.nodes('//Cuenta') AS cta(Item)
        INNER JOIN dbo.Persona AS p
            ON (p.ValorDocumentoIdentidad = cta.Item.value('@ValorDocumentoIdentidadDelCliente', 'VARCHAR(32)'))
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.Cuenta AS c
            WHERE (c.NumeroCuenta = cta.Item.value('@NumeroCuenta', 'VARCHAR(32)'))
        );

        SELECT
            @idx = MIN(cn.Secuencia)
            , @maxIdx = MAX(cn.Secuencia)
        FROM @CuentasNuevas AS cn;

        WHILE (@idx IS NOT NULL AND @idx <= @maxIdx)
        BEGIN
            INSERT dbo.Cuenta (
                IdCAhorrista
                , IdTipoCuentaAhorro
                , NumeroCuenta
                , FechaCreacion
                , Saldo
                , AcumuladosSinpe
                , FechaAcumuladosSinpe
            )
            SELECT
                cn.IdCAhorrista
                , cn.IdTipoCuentaAhorro
                , cn.NumeroCuenta
                , cn.FechaCreacion
                , cn.Saldo
                , 0.00
                , NULL
            FROM @CuentasNuevas AS cn
            WHERE (cn.Secuencia = @idx);

            SET @idx = @idx + 1;
        END;

        -- 5. Registrar en Beneficiario a las personas designadas como beneficiarias
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

        -- 6. Insertar relacion en BenefDeCA
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

        -- 7. Insertar Usuarios (si vienen en el XML)
        INSERT dbo.Usuario (
            IdPersona
            , NombreUsuario
            , Contrasena
            , flagEsAdministrador
        )
        SELECT
            p.Id
            , usr.Item.value('@User', 'VARCHAR(64)')
            , usr.Item.value('@Pass', 'VARCHAR(64)')
            , CASE WHEN (usr.Item.value('@EsAdministrador', 'INT') = 1) THEN 1 ELSE 0 END
        FROM @inXmlDia.nodes('//Usuario') AS usr(Item)
        INNER JOIN dbo.Persona AS p
            ON (p.ValorDocumentoIdentidad = usr.Item.value('@ValorDocId', 'VARCHAR(32)'))
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.Usuario AS u
            WHERE (u.NombreUsuario = usr.Item.value('@User', 'VARCHAR(64)'))
        );

        -- 8. Insertar UsuarioPuedeVer (si viene en el XML)
        INSERT dbo.UsuarioPuedeVer (
            IdUsuario
            , IdCuenta
        )
        SELECT
            u.Id
            , c.Id
        FROM @inXmlDia.nodes('//UsuarioPuedeVer') AS upv(Item)
        INNER JOIN dbo.Usuario AS u
            ON (u.NombreUsuario = upv.Item.value('@User', 'VARCHAR(64)'))
        INNER JOIN dbo.Cuenta AS c
            ON (c.NumeroCuenta = upv.Item.value('@NumeroCuenta', 'VARCHAR(32)'))
        WHERE NOT EXISTS (
            SELECT 1
            FROM dbo.UsuarioPuedeVer AS uv
            WHERE (uv.IdUsuario = u.Id)
                AND (uv.IdCuenta = c.Id)
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