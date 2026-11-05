
--insertar beneficiario a una cuenta

--Ejemplo de ejecucion
--DECLARE @resultCode INT;
--EXEC dbo.InsertarBeneficiario
--     @inIdUsuario = 1
--     , @inNumeroCuenta = '11000001'
--     , @inIdTipoDocuIdentidad = 1
--     , @inValorDocumentoIdentidad = '119290351'
--     , @inNombre = 'Kendall Ejemplo'
--     , @inFechaNacimiento = '2005-02-27'
--     , @inEmail = 'ejemploKen@correo.com'
--     , @inTelefono1 = '12341234'
--     , @inTelefono2 = '43214321'
--     , @inIdParentesco = 6
--     , @inPorcentaje = 25
--     , @inIP = '111.222.0.10'
--     , @outResultCode = @resultCode OUTPUT;

CREATE PROCEDURE dbo.InsertarBeneficiario
    @inIdUsuario INT
    , @inNumeroCuenta VARCHAR(32)
    , @inIdTipoDocuIdentidad INT
    , @inValorDocumentoIdentidad VARCHAR(32)
    , @inNombre VARCHAR(64)
    , @inFechaNacimiento DATE
    , @inEmail VARCHAR(128)
    , @inTelefono1 VARCHAR(32)
    , @inTelefono2 VARCHAR(32)
    , @inIdParentesco INT
    , @inPorcentaje INT
    , @inIP VARCHAR(64)
    , @outResultCode INT OUTPUT --codigo del resultado
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @idCuenta INT;
        DECLARE @idPersona INT;
        DECLARE @cantActivos INT;
        DECLARE @flagPersonaExiste BIT = 0;
        DECLARE @flagParentescoExiste BIT = 0;
        DECLARE @flagTipoDocExiste BIT = 0;
        DECLARE @flagYaEsBeneficiario BIT = 0;
        DECLARE @jsonDespues NVARCHAR(MAX);
        SET @outResultCode = 0; 

        SELECT @idCuenta = cuenta.Id --que el usuario pueda ver esa cuenta
        FROM dbo.UsuarioPuedeVer puedeVer
        INNER JOIN dbo.Cuenta cuenta
            ON cuenta.Id = puedeVer.IdCuenta
        WHERE puedeVer.IdUsuario = @inIdUsuario
            AND cuenta.NumeroCuenta = @inNumeroCuenta;

        SELECT @idPersona = persona.Id --comprobar el id
        FROM dbo.Persona persona
        WHERE persona.ValorDocumentoIdentidad = @inValorDocumentoIdentidad;

        IF (@idPersona IS NOT NULL)
        BEGIN
            SET @flagPersonaExiste = 1;
        END;

        IF (EXISTS (SELECT 1 --comprobar el parentezco si existe
                    FROM dbo.Parentesco parentesco
                    WHERE parentesco.Id = @inIdParentesco))
        BEGIN
            SET @flagParentescoExiste = 1;
        END;

        IF (EXISTS (SELECT 1 --comprobar el documento si existe
                    FROM dbo.TipoDocuIdentidad tipoDocu
                    WHERE tipoDocu.Id = @inIdTipoDocuIdentidad))
        BEGIN
            SET @flagTipoDocExiste = 1;
        END;

        SELECT @cantActivos = COUNT(beneficiarioCuenta.Id) --contar la cantidad de beneficiarios activos en la cuenta (maximo 3)
        FROM dbo.BenefDeCA beneficiarioCuenta
        WHERE beneficiarioCuenta.IdCuenta = @idCuenta
            AND beneficiarioCuenta.flagActivo = 1;

        IF (EXISTS (SELECT 1 --comprobar si es un beneficiario activo ya de la cuenta
                    FROM dbo.BenefDeCA beneficiarioCuenta
                    WHERE beneficiarioCuenta.IdCuenta = @idCuenta
                        AND beneficiarioCuenta.IdBeneficiario = @idPersona
                        AND beneficiarioCuenta.flagActivo = 1))
        BEGIN
            SET @flagYaEsBeneficiario = 1;
        END;

        IF (@idCuenta IS NULL) --validaciones
        BEGIN
            SET @outResultCode = 50003; --50003 error en la cuenta (no es del usuario)
        END
        ELSE IF (@cantActivos >= 3)
        BEGIN
            SET @outResultCode = 50004; --50004 error en benefic (mas de 3 benefic activos)
        END
        ELSE IF ((@inPorcentaje < 0) OR (@inPorcentaje > 100))
        BEGIN
            SET @outResultCode = 50005; --50005 error en el porcentaje (fuera del rango normal)
        END
        ELSE IF (@flagParentescoExiste = 0)
        BEGIN
            SET @outResultCode = 50006; --50006 error en parentesco (parentesco no existe)
        END
        ELSE IF (@flagTipoDocExiste = 0)
        BEGIN
            SET @outResultCode = 50007; --50007 error en el tipo de docu (tipo de docu no existe)
        END
        ELSE IF (@flagYaEsBeneficiario = 1)
        BEGIN
            SET @outResultCode = 50008; --50008 error ya es beneficiario
        END;

        IF (@outResultCode = 0)
        BEGIN

            SET @jsonDespues = '{"NumeroCuenta":"' + @inNumeroCuenta --armar bitacora, antes del transaction porque es un calculo previo
                + '","ValorDocumentoIdentidad":"' + @inValorDocumentoIdentidad
                + '","Nombre":"' + @inNombre
                + '","IdParentesco":' + CONVERT(VARCHAR(8), @inIdParentesco)
                + ',"Porcentaje":' + CONVERT(VARCHAR(8), @inPorcentaje) + '}';

            BEGIN TRANSACTION;

            IF (@flagPersonaExiste = 0) --si no existe se crea
            BEGIN
                INSERT dbo.Persona (
                    IdTipoDocuIdentidad
                    , ValorDocumentoIdentidad
                    , Nombre
                    , FechaNacimiento
                    , Email
                )
                SELECT @inIdTipoDocuIdentidad
                    , @inValorDocumentoIdentidad
                    , @inNombre
                    , @inFechaNacimiento
                    , @inEmail;

                SELECT @idPersona = persona.Id
                FROM dbo.Persona persona
                WHERE persona.ValorDocumentoIdentidad = @inValorDocumentoIdentidad;

                INSERT dbo.Telefono (
                    IdPersona
                    , Numero
                )
                SELECT @idPersona
                    , @inTelefono1;

                INSERT dbo.Telefono (
                    IdPersona
                    , Numero
                )
                SELECT @idPersona
                    , @inTelefono2;
            END;

            INSERT dbo.Beneficiario ( --darle un rol
                Id
            )
            SELECT @idPersona
            WHERE NOT EXISTS ( --evitar duplicar el rol
                SELECT 1
                FROM dbo.Beneficiario beneficiario
                WHERE beneficiario.Id = @idPersona
            );

            INSERT dbo.BenefDeCA ( --cuenta-beneficiario
                IdCuenta
                , IdBeneficiario
                , IdParentesco
                , Porcentaje
                , flagActivo
                , FechaDesactivacion
            )
            SELECT @idCuenta
                , @idPersona
                , @inIdParentesco
                , @inPorcentaje
                , 1
                , NULL;


            INSERT dbo.Bitacora (
                IdUsuario
                , IdTipoOperacion
                , IP
                , JsonAntes --seria NULL ya que no habia nada antes 
                , JsonDespues --guarda lo que se inserto
            )
            SELECT @inIdUsuario
                , 3 --3 es agregar beneficiario
                , @inIP
                , NULL
                , @jsonDespues;

            COMMIT TRANSACTION;
        END;
    END TRY

    BEGIN CATCH

        ROLLBACK TRANSACTION;

        INSERT dbo.DBErrors ( --guardar el error en DBErrores 
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