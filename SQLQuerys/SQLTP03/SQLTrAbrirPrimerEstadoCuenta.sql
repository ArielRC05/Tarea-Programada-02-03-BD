
CREATE TRIGGER dbo.TrAbrirPrimerEstadoCuenta
ON dbo.Cuenta
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    INSERT dbo.EstadoCuenta (
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
        , NULL   --el saldo minimo se fija con el primer movimiento
        , 0
        , 0
        , 0
        , 0
    FROM inserted I
    ORDER BY I.Id;

    SET NOCOUNT OFF;
END;

