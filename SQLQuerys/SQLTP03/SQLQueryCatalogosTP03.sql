USE TareaAhorros
--catalogo lo cual implica sin IDENTITY llega por el XML
CREATE TABLE dbo.TipoMovimiento (
    Id INT NOT NULL
    , Nombre VARCHAR(64) NOT NULL
    , flagEsCredito BIT NOT NULL --1 suma al saldo y 0 resta
    , flagGeneraComprobante BIT NOT NULL --1 si indica que el movimiento envia comprobante al email del dueno
    , flagEsATM BIT NOT NULL --1 es operacion en cajero automatico
    , flagEsCajeroHumano BIT NOT NULL --1 es operacion en cajero humano
    , flagEsSinpe BIT NOT NULL --1 es sinpe
    , CONSTRAINT Pk_TipoMovimiento PRIMARY KEY (Id)
    , CONSTRAINT NombreUnico_TipoMovimiento UNIQUE (Nombre)
);