
--"eliminar" un beneficiario de una cuenta
--Ejemplo de ejecucion
--DECLARE @resultCode INT;
--EXEC dbo.EliminarBeneficiario
--     @inIdUsuario = 1
--     , @inNumeroCuenta = '11000001'
--     , @inIdBenefDeCA = 1
--     , @inIP = '111.222.0.10'
--     , @outResultCode = @resultCode OUTPUT;

CREATE PROCEDURE dbo.EliminarBeneficiario
    @inIdUsuario INT
    , @inNumeroCuenta VARCHAR(32)
    , @inIdBenefDeCA INT
    , @inIP VARCHAR(64)
    , @outResultCode INT OUTPUT --codigo del resultado
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @idCuenta INT;
        DECLARE @idPersona INT;
        DECLARE @valorDocumento VARCHAR(32);
        DECLARE @nombreAntes VARCHAR(64);
        DECLARE @idParentescoAntes INT;
        DECLARE @porcentajeAntes INT;
        DECLARE @fechaHoy DATE;
        DECLARE @jsonAntes NVARCHAR(MAX);

        SET @outResultCode = 0;

        SELECT @idCuenta = cuenta.Id --si no se ve la cuenta queda NULL
        FROM dbo.UsuarioPuedeVer puedeVer
        INNER JOIN dbo.Cuenta cuenta
            ON cuenta.Id = puedeVer.IdCuenta
        WHERE puedeVer.IdUsuario = @inIdUsuario
            AND cuenta.NumeroCuenta = @inNumeroCuenta;

        SELECT @idPersona = beneficiarioCuenta.IdBeneficiario --datos actuales del beneficiario activo, si no existe queda NULL
            , @valorDocumento = persona.ValorDocumentoIdentidad
            , @nombreAntes = persona.Nombre
            , @idParentescoAntes = beneficiarioCuenta.IdParentesco
            , @porcentajeAntes = beneficiarioCuenta.Porcentaje
        FROM dbo.BenefDeCA beneficiarioCuenta
        INNER JOIN dbo.Persona persona
            ON persona.Id = beneficiarioCuenta.IdBeneficiario
        WHERE beneficiarioCuenta.Id = @inIdBenefDeCA
            AND beneficiarioCuenta.IdCuenta = @idCuenta
            AND beneficiarioCuenta.flagActivo = 1;

        IF (@idCuenta IS NULL) --validaciones
        BEGIN
            SET @outResultCode = 50003; --50003 error en la cuenta (no es del usuario)
        END
        ELSE IF (@idPersona IS NULL)
        BEGIN
            SET @outResultCode = 50009; --50009 error beneficiario no existe o no esta activo
        END;

        IF (@outResultCode = 0)
        BEGIN
            SET @fechaHoy = CONVERT(DATE, GETDATE()); --pre calculos antes de la transaction

            SET @jsonAntes = '{"NumeroCuenta":"' + @inNumeroCuenta
                + '","ValorDocumentoIdentidad":"' + @valorDocumento
                + '","Nombre":"' + @nombreAntes
                + '","IdParentesco":' + CONVERT(VARCHAR(8), @idParentescoAntes)
                + ',"Porcentaje":' + CONVERT(VARCHAR(8), @porcentajeAntes) + '}';

            BEGIN TRANSACTION;

            UPDATE dbo.BenefDeCA --eliminacion (logica ya que solo se apaga la bandera y se guarda la fecha)
            SET flagActivo = 0
                , FechaDesactivacion = @fechaHoy
            WHERE Id = @inIdBenefDeCA;

            INSERT dbo.Bitacora ( --bitacora
                IdUsuario
                , IdTipoOperacion
                , IP
                , JsonAntes --lo que habia antes de eliminar
                , JsonDespues --NULL porque ya no queda activo
            )
            SELECT @inIdUsuario
                , 5 --5 es eliminar beneficiario
                , @inIP
                , @jsonAntes
                , NULL;

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
GO