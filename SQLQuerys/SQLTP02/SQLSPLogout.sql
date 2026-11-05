--logout

--Ejemplo de ejecucion:
--DECLARE @resultCode INT;
--EXEC dbo.Logout
--     @inIdUsuario = 1
--     , @inIP = '192.168.0.10'
--     , @outResultCode = @resultCode OUTPUT;
CREATE PROCEDURE dbo.Logout
    @inIdUsuario INT
    , @inIP VARCHAR(64)
    , @outResultCode INT OUTPUT -- codigo del resultado
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET @outResultCode = 0;

        INSERT dbo.Bitacora (
            IdUsuario
            , IdTipoOperacion
            , IP
            , JsonAntes
            , JsonDespues
        )
        SELECT @inIdUsuario
            , 2 --2 es logout
            , @inIP
            , NULL
            , NULL;
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
