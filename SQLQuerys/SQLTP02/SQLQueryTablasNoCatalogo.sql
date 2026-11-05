-- Tablas No catalogo (llaves con identity)

CREATE TABLE dbo.Persona (
    Id INT IDENTITY(1,1) NOT NULL
    , IdTipoDocuIdentidad INT NOT NULL
    , ValorDocumentoIdentidad VARCHAR(32) NOT NULL
    , Nombre VARCHAR(64) NOT NULL
    , FechaNacimiento DATE NOT NULL --DATE: almacena la fecha en formato: año-mes-dia
    , Email VARCHAR(128) NOT NULL
    , CONSTRAINT Pk_Persona PRIMARY KEY (Id)
    , CONSTRAINT DocuUnico_PersonaValorDocuId UNIQUE (ValorDocumentoIdentidad)
    , CONSTRAINT Fk_PersonaTipoDocuId FOREIGN KEY (IdTipoDocuIdentidad) REFERENCES dbo.TipoDocuIdentidad (Id) --REFERENCES se refiere a que debe existir ahi para hacerlo
);

CREATE TABLE dbo.CAhorrista (
    Id INT NOT NULL 
    , CONSTRAINT Pk_CAhorrista PRIMARY KEY (Id)
    , CONSTRAINT Fk_CAhorristaPersona FOREIGN KEY (Id) REFERENCES dbo.Persona (Id)
);

CREATE TABLE dbo.Beneficiario (
    Id INT NOT NULL
    , CONSTRAINT Pk_Beneficiario PRIMARY KEY (Id)
    , CONSTRAINT Fk_BeneficiarioPersona FOREIGN KEY (Id) REFERENCES dbo.Persona (Id)
);

CREATE TABLE dbo.Telefono (
    Id INT IDENTITY(1,1) NOT NULL
    , IdPersona INT NOT NULL
    , Numero VARCHAR(32) NOT NULL
    , CONSTRAINT Pk_Telefono PRIMARY KEY (Id)
    , CONSTRAINT Fk_TelefonoPersona FOREIGN KEY (IdPersona) REFERENCES dbo.Persona (Id)
);

CREATE TABLE dbo.Cuenta (
    Id INT IDENTITY(1,1) NOT NULL
    , IdCAhorrista INT NOT NULL
    , IdTipoCuentaAhorro INT NOT NULL
    , NumeroCuenta VARCHAR(32) NOT NULL
    , FechaCreacion DATE NOT NULL
    , Saldo DECIMAL(18,2) NOT NULL
    , CONSTRAINT Pk_Cuenta PRIMARY KEY (Id)
    , CONSTRAINT NumCuentaUnico_CuentaNumeroCuenta UNIQUE (NumeroCuenta)
    , CONSTRAINT Fk_CuentaCAhorrista FOREIGN KEY (IdCAhorrista) REFERENCES dbo.CAhorrista (Id)
    , CONSTRAINT Fk_CuentaTipoCuentaAhorro FOREIGN KEY (IdTipoCuentaAhorro) REFERENCES dbo.TipoCuentaAhorro (Id)
);

CREATE TABLE dbo.BenefDeCA (
    Id INT IDENTITY(1,1) NOT NULL
    , IdCuenta INT NOT NULL
    , IdBeneficiario INT NOT NULL
    , IdParentesco INT NOT NULL
    , Porcentaje INT NOT NULL
    , flagActivo BIT NOT NULL DEFAULT 1 --BIT hace de boleano (0,1) para saber si esta activo o no, DEFAULT coloca un valor inicial
    , FechaDesactivacion DATE NULL --nulo si esta activo
    , CONSTRAINT Pk_BenefDeCA PRIMARY KEY (Id)
    , CONSTRAINT Fk_BenefDeCACuenta FOREIGN KEY (IdCuenta) REFERENCES dbo.Cuenta (Id)
    , CONSTRAINT Fk_BenefDeCABeneficiario FOREIGN KEY (IdBeneficiario) REFERENCES dbo.Beneficiario (Id)
    , CONSTRAINT Fk_BenefDeCAParentesco FOREIGN KEY (IdParentesco) REFERENCES dbo.Parentesco (Id)
);

CREATE TABLE dbo.EstadoCuenta (
    Id INT IDENTITY(1,1) NOT NULL
    , IdCuenta INT NOT NULL
    , FechaInicio DATE NOT NULL
    , FechaFin DATE NOT NULL
    , SaldoInicial DECIMAL(18,2) NOT NULL
    , SaldoFinal DECIMAL(18,2) NOT NULL
    , SaldoMinimo DECIMAL(18,2) NOT NULL
    , Intereses DECIMAL(18,2) NOT NULL DEFAULT 0
    , CantRetiros INT NOT NULL DEFAULT 0
    , CantDepositos INT NOT NULL DEFAULT 0
    , CantTransferenciasEntrantes INT NOT NULL DEFAULT 0
    , CantTransferenciasSalientes INT NOT NULL DEFAULT 0
    , CONSTRAINT Pk_EstadoCuenta PRIMARY KEY (Id)
    , CONSTRAINT Fk_EstadoCuentaCuenta FOREIGN KEY (IdCuenta) REFERENCES dbo.Cuenta (Id)
);

CREATE TABLE dbo.Usuario (
    Id INT IDENTITY(1,1) NOT NULL
    , IdPersona INT NOT NULL
    , NombreUsuario VARCHAR(64) NOT NULL
    , Contrasena VARCHAR(64) NOT NULL
    , flagEsAdministrador BIT NOT NULL
    , CONSTRAINT Pk_Usuario PRIMARY KEY (Id)
    , CONSTRAINT Unico_UsuarioNombreUsuario UNIQUE (NombreUsuario)
    , CONSTRAINT Fk_UsuarioPersona FOREIGN KEY (IdPersona) REFERENCES dbo.Persona (Id)
);
 
CREATE TABLE dbo.UsuarioPuedeVer (
    Id INT IDENTITY(1,1) NOT NULL
    , IdUsuario INT NOT NULL
    , IdCuenta INT NOT NULL
    , CONSTRAINT Pk_UsuarioPuedeVer PRIMARY KEY (Id)
    , CONSTRAINT Unico_UsuarioPuedeVer UNIQUE (IdUsuario, IdCuenta)
    , CONSTRAINT Fk_UsuarioPuedeVerUsuario FOREIGN KEY (IdUsuario) REFERENCES dbo.Usuario (Id)
    , CONSTRAINT Fk_UsuarioPuedeVerCuenta FOREIGN KEY (IdCuenta) REFERENCES dbo.Cuenta (Id)
);
 
CREATE TABLE dbo.Bitacora (
    Id INT IDENTITY(1,1) NOT NULL
    , IdUsuario INT NOT NULL
    , IdTipoOperacion INT NOT NULL
    , IP VARCHAR(64) NULL
    , JsonAntes NVARCHAR(MAX) NULL --antes de actualizar
    , JsonDespues NVARCHAR(MAX) NULL --despues de actualizar
    , PostTime DATETIME NOT NULL DEFAULT GETDATE() --fecha y hora actual
    , CONSTRAINT Pk_Bitacora PRIMARY KEY (Id)
    , CONSTRAINT Fk_BitacoraUsuario FOREIGN KEY (IdUsuario) REFERENCES dbo.Usuario (Id)
    , CONSTRAINT Fk_BitacoraTipoOperacion FOREIGN KEY (IdTipoOperacion) REFERENCES dbo.TipoOperacion (Id)
);

CREATE TABLE dbo.DBErrors ( --tabla para los errores
    Id INT IDENTITY(1,1) NOT NULL
    , NumeroError INT NULL
    , EstadoError INT NULL
    , SeveridadError INT NULL
    , LineaDeError INT NULL
    , ProcedureError VARCHAR(128) NULL
    , MensajeError VARCHAR(MAX) NULL
    , HoraError DATETIME NOT NULL DEFAULT GETDATE()
    , CONSTRAINT Pk_DBErrors PRIMARY KEY (Id)
);