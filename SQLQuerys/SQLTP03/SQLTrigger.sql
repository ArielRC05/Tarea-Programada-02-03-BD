
CREATE TRIGGER dbo.TrAbrirPrimerEstadoCuenta
on dbo.Cuenta
AFTER INSERT --el After significa que se ejecuta despues del insert
AS 
BEGIN 
	SET NOCOUNT ON;

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
		FROM inserted I --inserted es una tabla logica con las filas insertadas
		ORDER BY I.Id;
	
	SET NOCOUNT OFF;
END;

