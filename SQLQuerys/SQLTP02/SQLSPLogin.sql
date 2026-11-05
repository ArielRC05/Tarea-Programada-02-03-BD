USE TareaAhorros;
GO

--login SP
--Ejemplo de ejecucion
--DECLARE @resultCode INT;
--EXEC dbo.Login
--     @inUser = 'jaguero'
--     , @inPass = 'LaFacil'
--     , @inIP = '192.168.0.10'
--     , @outResultCode = @resultCode OUTPUT;
CREATE PROCEDURE dbo.Login
    @inUser VARCHAR(64)
    , @inPass VARCHAR(64) --contrasena
    , @inIP VARCHAR(64) --el IP del usuario
    , @outResultCode INT OUTPUT --codigo del resultado
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @idUsuario INT;

        SET @outResultCode = 0;

        SELECT @idUsuario = usuario.Id
        FROM dbo.Usuario usuario
        WHERE usuario.NombreUsuario = @inUser --nombre y contrasena iguales
            AND usuario.Contrasena = @inPass;

        IF (@idUsuario IS NULL)
        BEGIN
            SET @outResultCode = 50002; --error en login
        END
        ELSE
        BEGIN
            INSERT dbo.Bitacora (
                IdUsuario
                , IdTipoOperacion
                , IP
                , JsonAntes
                , JsonDespues
            )
            SELECT @idUsuario
                , 1 --1 es login
                , @inIP
                , NULL
                , NULL;

            SELECT usuario.Id --dar el usuario y si es admin
                , usuario.flagEsAdministrador
            FROM dbo.Usuario usuario
            WHERE usuario.Id = @idUsuario;
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