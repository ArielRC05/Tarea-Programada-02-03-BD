USE TareaAhorros;


ALTER TABLE dbo.EstadoCuenta
ADD CantOperacionesATM INT NOT NULL DEFAULT 0 --cantidad de operaciones cajero ATM en el dia
	, CantOperacionesCajeroHumano INT NOT NULL DEFAULT 0; --operaciones en cajero humano en el dia

ALTER TABLE dbo.Cuenta
ADD AcumuladosSinpe DECIMAL (18,2) NOT NULL DEFAULT 0 --sinpe saliente 
	, FechaAcumuladosSinpe DATE NULL; --si nunca se envia un sinpe esto es null

ALTER TABLE dbo.TipoCuentaAhorro
ADD MontoMaxSinpeDiario MONEY NOT NULL DEFAULT 0 --monto maximo diario de sinpe saliente (que no tiene comision)
    , ComisionSinpe MONEY NOT NULL DEFAULT 0; --comision al suprar el monto maximo diario