
--editar beneficiario (nombre, parentesco o porcentaje de un benef activo)
--Ejemplo de ejecucion
--DECLARE @resultCode INT;
--EXEC dbo.EditarBeneficiario
--     @inIdUsuario = 1
--     , @inNumeroCuenta = '11000001'
--     , @inIdBenefDeCA = 1
--     , @inNombre = 'Kendall Ejemplo Editado'
--     , @inIdParentesco = 5
--     , @inPorcentaje = 40
--     , @inIP = '111.222.0.10'
--     , @outResultCode = @resultCode OUTPUT;

CREATE PROCEDURE dbo.EditarBeneficiario
    @inIdUsuario INT
    , @inNumeroCuenta VARCHAR(32)
    , @inIdBenefDeCA INT
    , @inNombre VARCHAR(64)
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
        DECLARE @nombreAntes VARCHAR(64);
        DECLARE @idParentescoAntes INT;
        DECLARE @porcentajeAntes INT;
        DECLARE @idTipoOperacion INT;
        DECLARE @flagParentescoExiste BIT = 0;
        DECLARE @flagSoloPorcentaje BIT = 0;
        DECLARE @jsonAntes NVARCHAR(MAX);
        DECLARE @jsonDespues NVARCHAR(MAX);

        SET @outResultCode = 0;

        SELECT @idCuenta = cuenta.Id ---si no se ve la cuenta queda NULL
        FROM dbo.UsuarioPuedeVer puedeVer
        INNER JOIN dbo.Cuenta cuenta
            ON cuenta.Id = puedeVer.IdCuenta
        WHERE puedeVer.IdUsuario = @inIdUsuario
            AND cuenta.NumeroCuenta = @inNumeroCuenta;

        SELECT @idPersona = beneficiarioCuenta.IdBeneficiario --datos actuales del beneficiario, si no encuentra NULL
            , @nombreAntes = persona.Nombre
            , @idParentescoAntes = beneficiarioCuenta.IdParentesco
            , @porcentajeAntes = beneficiarioCuenta.Porcentaje
        FROM dbo.BenefDeCA beneficiarioCuenta
        INNER JOIN dbo.Persona persona
            ON persona.Id = beneficiarioCuenta.IdBeneficiario
        WHERE beneficiarioCuenta.Id = @inIdBenefDeCA
            AND beneficiarioCuenta.IdCuenta = @idCuenta
            AND beneficiarioCuenta.flagActivo = 1;

        IF (EXISTS (SELECT 1 --validar el nuevo parentesco
                    FROM dbo.Parentesco parentesco
                    WHERE parentesco.Id = @inIdParentesco))
        BEGIN
            SET @flagParentescoExiste = 1;
        END;

        IF (@idCuenta IS NULL) --validaciones
        BEGIN
            SET @outResultCode = 50003; --50003 error en la cuenta (no es del usuario)
        END
        ELSE IF (@idPersona IS NULL)
        BEGIN
            SET @outResultCode = 50009; --50009 error beneficiario no existe o no esta activo
        END
        ELSE IF ((@inPorcentaje < 0) OR (@inPorcentaje > 100))
        BEGIN
            SET @outResultCode = 50005; --50005 error en el porcentaje (fuera del rango normal)
        END
        ELSE IF (@flagParentescoExiste = 0)
        BEGIN
            SET @outResultCode = 50006; --50006 error en parentesco (parentesco no existe)
        END;

        IF (@outResultCode = 0)
        BEGIN

            SET @idTipoOperacion = 4; --tipo operacion 4 si cambio nombre, parentesco, porcentaje

            IF ((@inNombre = @nombreAntes)
                AND (@inIdParentesco = @idParentescoAntes)
                AND (@inPorcentaje <> @porcentajeAntes))
            BEGIN
                SET @flagSoloPorcentaje = 1;
            END;

            IF (@flagSoloPorcentaje = 1)
            BEGIN
                SET @idTipoOperacion = 6; --operacion 6 si no cambio nombre ni parentesco y si porcentaje
            END;

            SET @jsonAntes = '{"NumeroCuenta":"' + @inNumeroCuenta --json antes y depsues antes de la transaccion 
                + '","Nombre":"' + @nombreAntes
                + '","IdParentesco":' + CONVERT(VARCHAR(8), @idParentescoAntes)
                + ',"Porcentaje":' + CONVERT(VARCHAR(8), @porcentajeAntes) + '}';

            SET @jsonDespues = '{"NumeroCuenta":"' + @inNumeroCuenta
                + '","Nombre":"' + @inNombre
                + '","IdParentesco":' + CONVERT(VARCHAR(8), @inIdParentesco)
                + ',"Porcentaje":' + CONVERT(VARCHAR(8), @inPorcentaje) + '}';

            BEGIN TRANSACTION;

            UPDATE dbo.Persona --actualizar nombre (el nombre lo tiene dbo persona no dbo benefdeca)
            SET Nombre = @inNombre
            WHERE Id = @idPersona;

            UPDATE dbo.BenefDeCA --actulizar parentesco y porcentaje
            SET IdParentesco = @inIdParentesco
                , Porcentaje = @inPorcentaje
            WHERE Id = @inIdBenefDeCA;

            INSERT dbo.Bitacora ( --bitacora
                IdUsuario
                , IdTipoOperacion
                , IP
                , JsonAntes
                , JsonDespues
            )
            SELECT @inIdUsuario
                , @idTipoOperacion
                , @inIP
                , @jsonAntes
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
