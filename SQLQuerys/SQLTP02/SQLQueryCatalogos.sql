
-- Catalogos (no tienen IDENTITY en el Id, se insertan como vine en el XML)
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
    , SaldoMinimo MONEY NOT NULL
    , MultaSaldoMin MONEY NOT NULL
    , CargoAnual MONEY NOT NULL
    , NumRetirosHumano INT NOT NULL
    , NumRetirosAutomatico INT NOT NULL
    , ComisionHumano MONEY NOT NULL
    , ComisionAutomatico MONEY NOT NULL
    , Interes DECIMAL(5,2) NOT NULL -- tasa de interes con 5 digitos y 2 decimales
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
