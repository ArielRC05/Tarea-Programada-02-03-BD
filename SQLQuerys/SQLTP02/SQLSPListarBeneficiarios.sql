--listar los beneficiarios de una cuenta
--Ejemplo de ejecucion
--DECLARE @resultCode INT;
--EXEC dbo.ListarBeneficiarios
--     @inIdUsuario = 1
--     , @inNumeroCuenta = '11000001'
--     , @outResultCode = @resultCode OUTPUT;
CREATE PROCEDURE dbo.ListarBeneficiarios
    @inIdUsuario INT
    , @inNumeroCuenta VARCHAR(32)
    , @outResultCode INT OUTPUT -- codigo del resultado
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @idCuenta INT;

        SET @outResultCode = 0;

        --revisar que la cuenta si la pueda ver el usuario
        SELECT @idCuenta = cuenta.Id
        FROM dbo.UsuarioPuedeVer puedeVer
        INNER JOIN dbo.Cuenta cuenta
            ON cuenta.Id = puedeVer.IdCuenta
        WHERE puedeVer.IdUsuario = @inIdUsuario
            AND cuenta.NumeroCuenta = @inNumeroCuenta;

        IF (@idCuenta IS NULL)
        BEGIN
            SET @outResultCode = 50003; --50003 es error si la cuenta no es de ese usuario
        END
        ELSE
        BEGIN
            SELECT beneficiarioCuenta.Id AS IdBenefDeCA --beneficiario activo de la CA
                , persona.ValorDocumentoIdentidad
                , persona.Nombre
                , persona.FechaNacimiento
                , persona.Email
                , parentesco.Nombre AS Parentesco
                , beneficiarioCuenta.Porcentaje
            FROM dbo.BenefDeCA beneficiarioCuenta
            INNER JOIN dbo.Persona persona
                ON persona.Id = beneficiarioCuenta.IdBeneficiario --busca el id de la persona
            INNER JOIN dbo.Parentesco parentesco
                ON parentesco.Id = beneficiarioCuenta.IdParentesco --busca el parentesco
            WHERE beneficiarioCuenta.IdCuenta = @idCuenta
                AND beneficiarioCuenta.flagActivo = 1
            ORDER BY persona.Nombre;
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