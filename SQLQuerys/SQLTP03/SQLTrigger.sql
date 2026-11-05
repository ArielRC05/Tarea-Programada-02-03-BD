
CREATE TRIGGER dbo.TrAbrirPrimerEstadoCuenta
on dbo.Cuenta
AFTER INSERT --el After significa que se ejecuta despues del insert
AS 
BEGIN 
	SET NOCOUNT ON;

	BEGIN TRY

		INSERT dbo.EstadoCuenta(
			IdCuenta
			, FechaInicio
			, FechaFin
			, SaldoInicial
			, SaldoFinal
			, SaldoMinimo
			, CantTransferenciasEntrantes
			, CantTransferenciasSalientes
			, CantOperacionesATM
			, CantOperacionesCajeroHumano
		)
		SELECT I.Id
            , I.FechaCreacion
            , DATEADD(MONTH, 1, I.FechaCreacion)
            , I.Saldo
            , I.Saldo
            , I.Saldo
            , 0
            , 0
            , 0
            , 0
		FROM inserted I --inserted es una tabla temporal logica 
		ORDER BY I.Id;
	
	END TRY
	BEGIN CATCH

		INSERT dbo.DBErrors(
			NumeroError
			, EstadoError
			, SeveridadError
			, LineaDeError
			, ProcedureError
			, MensajeError
		)
		VALUES (
			ERROR_NUMBER()
			, ERROR_STATE()
			, ERROR_SEVERITY()
			, ERROR_LINE()
			, ERROR_PROCEDURE()
			, ERROR_MESSAGE()
		);

		THROW;
	END CATCH;

	SET NOCOUNT OFF;
END;

