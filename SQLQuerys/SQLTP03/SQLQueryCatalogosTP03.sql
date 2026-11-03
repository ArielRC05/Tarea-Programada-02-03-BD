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

CREATE TABLE dbo.TipoDocuIdentidad (
    Id INT NOT NULL
    , Nombre VARCHAR(64) NOT NULL
    , CONSTRAINT Pk_TipoDocuIdentidad PRIMARY KEY (Id) --indicamos que la llave primaria sera el Id y el nombre de la "regla"
    , CONSTRAINT NombreUnico_TipoDocuIdentidad UNIQUE (Nombre) --nombre unico
);

CREATE TABLE dbo.TipoMoneda (
    Id INT NOT NULL
    , Nombre VARCHAR(32) NOT NULL
    , Simbolo NVARCHAR(4) NOT NULL --NVARCHAR para los simbolos de colones, dolares y euros
    , CONSTRAINT Pk_TipoMoneda PRIMARY KEY (Id)
    , CONSTRAINT NombreUnico_TipoMoneda UNIQUE (Nombre)
);

CREATE TABLE dbo.Parentesco (
    Id INT NOT NULL
    , Nombre VARCHAR(32) NOT NULL
    , CONSTRAINT Pk_Parentesco PRIMARY KEY (Id)
    , CONSTRAINT NombreUnico_Parentesco UNIQUE (Nombre)
);

CREATE TABLE dbo.TipoCuentaAhorro (
    Id INT NOT NULL
    , IdTipoMoneda INT NOT NULL
    , Nombre VARCHAR(64) NOT NULL
    , SaldoMinimo DECIMAL(18,2) NOT NULL
    , MultaSaldoMin DECIMAL(18,2) NOT NULL
    , CargoMensual DECIMAL(18,2) NOT NULL
    , NumRetirosHumano INT NOT NULL
    , NumRetirosAutomatico INT NOT NULL
    , ComisionHumano DECIMAL(18,2) NOT NULL
    , ComisionAutomatico DECIMAL(18,2) NOT NULL
    , MontoMaxSinpeDiario DECIMAL(18,2) NOT NULL --suma maxima diaria de sinpe saliente sin comision
    , ComisionSinpe DECIMAL(18,2) NOT NULL --se cobra por cada sinpe que supere el maximo al dia
    , TasaInteresAnual DECIMAL(5,2) NOT NULL --porcentaje anual, tasa de intereses divido entre 12 al cierre
    , CONSTRAINT Pk_TipoCuentaAhorro PRIMARY KEY (Id)
    , CONSTRAINT NombreUnico_TipoCuentaAhorro UNIQUE (Nombre)
    , CONSTRAINT Fk_MonedaTipoCuentaAhorro FOREIGN KEY (IdTipoMoneda) REFERENCES dbo.TipoMoneda (Id) --Para establecer el tipo de moneda
);

CREATE TABLE dbo.TipoOperacion (
    Id INT NOT NULL
    , Nombre VARCHAR(64) NOT NULL
    , CONSTRAINT Pk_TipoOperacion PRIMARY KEY (Id)
    , CONSTRAINT NombreUnico_TipoOperacion UNIQUE (Nombre)
);
