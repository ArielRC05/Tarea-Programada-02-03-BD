USE TareaAhorros
--Estas no son tablas catalogo por lo que si cuentan con IDENTITY

CREATE TABLE dbo.Comprobante ( --almacenar los comprobantes de la cuenta
    Id INT IDENTITY(1,1) NOT NULL
    , IdCuenta INT NOT NULL
    , Fecha DATE NOT NULL
    , TextoEmail VARCHAR(512) NOT NULL
    , CONSTRAINT Pk_Comprobante PRIMARY KEY (Id)
    , CONSTRAINT Fk_ComprobanteCuenta FOREIGN KEY (IdCuenta) REFERENCES dbo.Cuenta (Id)
);

CREATE TABLE dbo.Movimiento ( --registrar las operaciones que se realizan sobre la cuenta
    Id INT IDENTITY(1,1) NOT NULL
    , IdEstadoCuenta INT NOT NULL
    , IdTipoMovimiento INT NOT NULL
    , IdComprobante INT NULL --nulo si no genera comprobante
    , Fecha DATE NOT NULL
    , Monto DECIMAL(18,2) NOT NULL
    , Descripcion VARCHAR(256) NOT NULL
    , NuevoSaldo DECIMAL(18,2) NOT NULL
    , PostTime DATETIME NOT NULL DEFAULT GETDATE()
    , CONSTRAINT Pk_Movimiento PRIMARY KEY (Id)
    , CONSTRAINT Fk_MovimientoEstadoCuenta FOREIGN KEY (IdEstadoCuenta) REFERENCES dbo.EstadoCuenta (Id)
    , CONSTRAINT Fk_MovimientoTipoMovimiento FOREIGN KEY (IdTipoMovimiento) REFERENCES dbo.TipoMovimiento (Id)
    , CONSTRAINT Fk_MovimientoComprobante FOREIGN KEY (IdComprobante) REFERENCES dbo.Comprobante (Id)
);

CREATE TABLE dbo.EventLog ( --para el control masivo
    Id INT IDENTITY(1,1) NOT NULL
    , IdTipoEvento INT NOT NULL --1 = cierre de estados del dia
    , FechaEvento DATE NOT NULL
    , Descripcion VARCHAR(256) NOT NULL
    , CantIdsPorProcesar INT NOT NULL DEFAULT 0
    , UltimoIdProcesado INT NOT NULL DEFAULT 0
    , CantIdsProcesados INT NOT NULL DEFAULT 0 --si es igual a CantIdsPorProcesar implica que el proceso termino
    , PostTime DATETIME NOT NULL DEFAULT GETDATE()
    , CONSTRAINT Pk_EventLog PRIMARY KEY (Id)
);