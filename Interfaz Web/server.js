const express = require('express');
const cors = require('cors');
const { sql, poolPromise } = require('./db');

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json());
app.use(express.static('Public')); // Servir los archivos estáticos de la interfaz

// Endpoint 1: Login (Bitácora TipoOperacion = 1)
app.post('/api/login', async (req, res) => {
    const { user, pass } = req.body;
    const ip = req.ip || req.connection.remoteAddress;

    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('inUser', sql.VarChar(64), user)
            .input('inPass', sql.VarChar(64), pass)
            .input('inIP', sql.VarChar(64), ip)
            .output('outResultCode', sql.Int)
            .execute('dbo.Login');

        const codigoResultado = result.output.outResultCode;

        if (codigoResultado === 0 && result.recordset.length > 0) {
            res.status(200).json({ mensaje: 'Login exitoso', usuario: result.recordset[0] });
        } else {
            res.status(401).json({ error: 'Usuario o contraseña incorrectos.', codigo: codigoResultado });
        }
    } catch (err) {
        console.error('Error al ejecutar dbo.Login:', err);
        res.status(500).json({ error: 'Error interno del servidor.' });
    }
});

// Endpoint 1.5: Logout (Bitácora TipoOperacion = 2)
app.post('/api/logout', async (req, res) => {
    const { idUsuario } = req.body;
    const ip = req.ip || req.connection.remoteAddress;

    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('inIdUsuario', sql.Int, idUsuario)
            .input('inIP', sql.VarChar(64), ip)
            .output('outResultCode', sql.Int)
            .execute('dbo.Logout');

        res.status(200).json({ codigoResultado: result.output.outResultCode });
    } catch (err) {
        console.error('Error al ejecutar dbo.Logout:', err);
        res.status(500).json({ error: 'Error interno del servidor.' });
    }
});

// Endpoint 2: Listar Cuentas del Usuario
app.get('/api/cuentas/:idUsuario', async (req, res) => {
    const { idUsuario } = req.params;

    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('inIdUsuario', sql.Int, idUsuario)
            .output('outResultCode', sql.Int)
            .execute('dbo.ListarCuentasUsuario');

        if (result.output.outResultCode === 0) {
            res.status(200).json(result.recordset);
        } else {
            res.status(400).json({ error: 'Error al listar las cuentas.', codigo: result.output.outResultCode });
        }
    } catch (err) {
        console.error('Error en dbo.ListarCuentasUsuario:', err);
        res.status(500).json({ error: 'Error interno del servidor.' });
    }
});

// Endpoint 3: Listar Beneficiarios
app.get('/api/beneficiarios/:idUsuario/:numeroCuenta', async (req, res) => {
    const { idUsuario, numeroCuenta } = req.params;

    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('inIdUsuario', sql.Int, idUsuario)
            .input('inNumeroCuenta', sql.VarChar(32), numeroCuenta)
            .output('outResultCode', sql.Int)
            .execute('dbo.ListarBeneficiarios');

        if (result.output.outResultCode === 0) {
            res.status(200).json(result.recordset);
        } else {
            res.status(400).json({ error: 'Error al listar beneficiarios.', codigo: result.output.outResultCode });
        }
    } catch (err) {
        console.error('Error en dbo.ListarBeneficiarios:', err);
        res.status(500).json({ error: 'Error interno del servidor.' });
    }
});

// Endpoint 4: Insertar Beneficiario (Bitácora TipoOperacion = 3)
app.post('/api/beneficiarios', async (req, res) => {
    const { idUsuario, numeroCuenta, idTipoDoc, valorDoc, nombre, fechaNacimiento, email, tel1, tel2, idParentesco, porcentaje } = req.body;
    const ip = req.ip || req.connection.remoteAddress;

    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('inIdUsuario', sql.Int, idUsuario)
            .input('inNumeroCuenta', sql.VarChar(32), numeroCuenta)
            .input('inIdTipoDocuIdentidad', sql.Int, idTipoDoc)
            .input('inValorDocumentoIdentidad', sql.VarChar(32), valorDoc)
            .input('inNombre', sql.VarChar(64), nombre)
            .input('inFechaNacimiento', sql.Date, fechaNacimiento)
            .input('inEmail', sql.VarChar(128), email)
            .input('inTelefono1', sql.VarChar(32), tel1)
            .input('inTelefono2', sql.VarChar(32), tel2)
            .input('inIdParentesco', sql.Int, idParentesco)
            .input('inPorcentaje', sql.Int, porcentaje)
            .input('inIP', sql.VarChar(64), ip)
            .output('outResultCode', sql.Int)
            .execute('dbo.InsertarBeneficiario');

        res.status(200).json({ codigoResultado: result.output.outResultCode });
    } catch (err) {
        console.error('Error en dbo.InsertarBeneficiario:', err);
        res.status(500).json({ error: 'Error interno del servidor.' });
    }
});

// Endpoint 5: Editar Beneficiario (Bitácora TipoOperacion = 4 y 6)
app.put('/api/beneficiarios', async (req, res) => {
    const { idUsuario, numeroCuenta, idBenefDeCA, nombre, idParentesco, porcentaje } = req.body;
    const ip = req.ip || req.connection.remoteAddress;

    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('inIdUsuario', sql.Int, idUsuario)
            .input('inNumeroCuenta', sql.VarChar(32), numeroCuenta)
            .input('inIdBenefDeCA', sql.Int, idBenefDeCA)
            .input('inNombre', sql.VarChar(64), nombre)
            .input('inIdParentesco', sql.Int, idParentesco)
            .input('inPorcentaje', sql.Int, porcentaje)
            .input('inIP', sql.VarChar(64), ip)
            .output('outResultCode', sql.Int)
            .execute('dbo.EditarBeneficiario');

        res.status(200).json({ codigoResultado: result.output.outResultCode });
    } catch (err) {
        console.error('Error en dbo.EditarBeneficiario:', err);
        res.status(500).json({ error: 'Error interno del servidor.' });
    }
});

// Endpoint 6: Eliminar Beneficiario - Borrado Lógico (Bitácora TipoOperacion = 5)
app.delete('/api/beneficiarios', async (req, res) => {
    const { idUsuario, numeroCuenta, idBenefDeCA } = req.body;
    const ip = req.ip || req.connection.remoteAddress;

    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('inIdUsuario', sql.Int, idUsuario)
            .input('inNumeroCuenta', sql.VarChar(32), numeroCuenta)
            .input('inIdBenefDeCA', sql.Int, idBenefDeCA)
            .input('inIP', sql.VarChar(64), ip)
            .output('outResultCode', sql.Int)
            .execute('dbo.EliminarBeneficiario');

        res.status(200).json({ codigoResultado: result.output.outResultCode });
    } catch (err) {
        console.error('Error en dbo.EliminarBeneficiario:', err);
        res.status(500).json({ error: 'Error interno del servidor.' });
    }
});

// =========================================================
// ENDPOINTS TP3: ESTADOS DE CUENTA Y DETALLE DE MOVIMIENTOS
// =========================================================

// Endpoint 7: Listar Estados de Cuenta (@inIdCuenta INT)
app.get('/api/estados/:idCuenta', async (req, res) => {
    const { idCuenta } = req.params;

    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('inIdCuenta', sql.Int, idCuenta)
            .output('outResultCode', sql.Int)
            .execute('dbo.ListarEstadosCuenta');

        if (result.output.outResultCode === 0) {
            res.status(200).json(result.recordset);
        } else {
            res.status(400).json({ error: 'Error al listar estados de cuenta.', codigo: result.output.outResultCode });
        }
    } catch (err) {
        console.error('Error en dbo.ListarEstadosCuenta:', err);
        res.status(500).json({ error: 'Error interno del servidor.' });
    }
});

// Endpoint 8: Consultar un Estado de Cuenta (@inIdEstadoCuenta INT)
app.get('/api/estado-cuenta/:idEstadoCuenta', async (req, res) => {
    const { idEstadoCuenta } = req.params;

    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('inIdEstadoCuenta', sql.Int, idEstadoCuenta)
            .output('outResultCode', sql.Int)
            .execute('dbo.ConsultarEstadoCuenta');

        if (result.output.outResultCode === 0 && result.recordset.length > 0) {
            res.status(200).json(result.recordset[0]);
        } else {
            res.status(400).json({ error: 'Error al consultar el estado de cuenta.', codigo: result.output.outResultCode });
        }
    } catch (err) {
        console.error('Error en dbo.ConsultarEstadoCuenta:', err);
        res.status(500).json({ error: 'Error interno del servidor.' });
    }
});

// Endpoint 9: Listar Movimientos de un Estado de Cuenta (@inIdEstadoCuenta INT)
app.get('/api/estado-cuenta/:idEstadoCuenta/movimientos', async (req, res) => {
    const { idEstadoCuenta } = req.params;

    try {
        const pool = await poolPromise;
        const result = await pool.request()
            .input('inIdEstadoCuenta', sql.Int, idEstadoCuenta)
            .output('outResultCode', sql.Int)
            .execute('dbo.ListarMovimientosEstadoCuenta');

        if (result.output.outResultCode === 0) {
            res.status(200).json(result.recordset);
        } else {
            res.status(400).json({ error: 'Error al listar los movimientos del estado de cuenta.', codigo: result.output.outResultCode });
        }
    } catch (err) {
        console.error('Error en dbo.ListarMovimientosEstadoCuenta:', err);
        res.status(500).json({ error: 'Error interno del servidor.' });
    }
});

app.listen(PORT, () => {
    console.log(`🚀 Servidor corriendo en http://localhost:${PORT}`);
});