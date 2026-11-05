--query para drop todo y corregir mejor 
USE TareaAhorros;
GO

DROP PROCEDURE IF EXISTS dbo.Login;
DROP PROCEDURE IF EXISTS dbo.Logout;
DROP PROCEDURE IF EXISTS dbo.ListarCuentasUsuario;
DROP PROCEDURE IF EXISTS dbo.ListarBeneficiarios;
DROP PROCEDURE IF EXISTS dbo.CargarDatos;
DROP PROCEDURE IF EXISTS dbo.CargarCatalogos;

DROP TABLE IF EXISTS dbo.Bitacora;
DROP TABLE IF EXISTS dbo.UsuarioPuedeVer;
DROP TABLE IF EXISTS dbo.EstadoCuenta;
DROP TABLE IF EXISTS dbo.BenefDeCA;
DROP TABLE IF EXISTS dbo.Cuenta;
DROP TABLE IF EXISTS dbo.Telefono;
DROP TABLE IF EXISTS dbo.Beneficiario;
DROP TABLE IF EXISTS dbo.CAhorrista;
DROP TABLE IF EXISTS dbo.Usuario;
DROP TABLE IF EXISTS dbo.Persona;
DROP TABLE IF EXISTS dbo.DBErrors;
DROP TABLE IF EXISTS dbo.TipoOperacion;
DROP TABLE IF EXISTS dbo.TipoCuentaAhorro;
DROP TABLE IF EXISTS dbo.Parentesco;
DROP TABLE IF EXISTS dbo.TipoMoneda;
DROP TABLE IF EXISTS dbo.TipoDocuIdentidad;
