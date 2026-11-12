IF DB_ID(N'SIGO_db') IS NULL
CREATE DATABASE SIGO_db;

GO
USE SIGO_db;
GO

CREATE TABLE dbo.oficio(
    id_oficio INT PRIMARY KEY IDENTITY(1,1),
    tipo_documento VARCHAR(20) NOT NULL,
    folio_oficio VARCHAR(20) NOT NULL,
    fecha_creacion DATETIME NOT NULL DEFAULT GETDATE(),
    tratamiento_oficio VARCHAR(20) NOT NULL,
    asunto NVARCHAR(200) NOT NULL,
    destinatario NVARCHAR(200) NOT NULL,
    cargo_destinatario NVARCHAR(100) NOT NULL,
    area NVARCHAR(100) NOT NULL,
    dir_administracion_gen NVARCHAR(200) NULL,
    direccion_administracion NVARCHAR(200) NULL,
    depertamento NVARCHAR(20) NULL,
    remitente NVARCHAR(200) NOT NULL,
    cargo_remitente NVARCHAR(100) NOT NULL,
    area_remitente NVARCHAR(100) NOT NULL,
    dependencia_remitente NVARCHAR(100) NULL,
    fecha_despacho DATETIME NOT NULL,
    fecha_recepcion DATETIME NOT NULL,
    estatus_oficio VARCHAR(20) NOT NULL DEFAULT 'Pendiente',
    doc_digital VARBINARY(MAX) NULL,
    CONSTRAINT UQ_folio_oficio UNIQUE (folio_oficio),
);

CREATE TABLE dbo.usuario(
    id_usuario INT PRIMARY KEY IDENTITY(1,1),
    nombre_usuario VARCHAR(100) NOT NULL,
    nombre_completo VARCHAR(200) NOT NULL,
    rfc_corto VARCHAR(8) NOT NULL,
    contraseña VARCHAR(100) NOT NULL,
    rol VARCHAR(50) NOT NULL DEFAULT ('Lectura'),
    fecha_creacion DATETIME NOT NULL DEFAULT GETDATE(),
    fecha_ultimo_acceso DATETIME NULL,
    estatus_usuario VARCHAR(20) NOT NULL DEFAULT 'Activo',
    CONSTRAINT UQ_nombre_usuario UNIQUE (nombre_usuario),
    CONSTRAINT UQ_usuario_nombre_completo UNIQUE (nombre_completo),
    CONSTRAINT CK_usuario_nombre_longitud CHECK (DATALENGTH(nombre_usuario) = 8),
    CONSTRAINT CK_usuario_rfc_corto CHECK (nombre_usuario NOT LIKE '%[^A-Z0-9&Ñ]%' AND nombre_usuario LIKE '[A-Z&Ñ][A-Z&Ñ][A-Z&Ñ][A-Z&Ñ][0-9][0-9][0-9][0-9][0-9][0-9]'),
    CONSTRAINT CK_usuario_rol CHECK (rol IN ('Administrador', 'Consultor', 'Lectura')),
    CONSTRAINT CK_usuario_estatus CHECK (estatus_usuario IN ('ACTIVO', 'BLOQUEADO', 'INACTIVO')),
);

CREATE TABLE dbo.bitacora_acceso (
    bitacora_id BIGINT IDENTITY(1,1) CONSTRAINT PK_bitacora_acceso PRIMARY KEY,
    usuario_id INT NULL,
    nombre_usuario VARCHAR(100) NOT NULL,
    fecha_hora DATETIME2(0) NOT NULL CONSTRAINT DF_bitacora_fecha DEFAULT (SYSUTCDATETIME()),
    resultado VARCHAR(15) NOT NULL,
    CONSTRAINT CK_bitacora_resultado CHECK (resultado IN ('EXITOSO', 'FALLIDO', 'CIERRE_SESION')),
    CONSTRAINT FK_bitacora_usuario FOREIGN KEY (usuario_id) REFERENCES dbo.usuario(usuario_id)
);
CREATE INDEX IX_bitacora_acceso_fecha ON dbo.bitacora_acceso (fecha_hora DESC, usuario_id);

/* Cada carga de Excel es auditable y puede reprocesarse sin perder su origen. */
CREATE TABLE dbo.carga_archivo (
    carga_id BIGINT IDENTITY(1,1) CONSTRAINT PK_carga_archivo PRIMARY KEY,
    usuario_id INT NOT NULL,
    nombre_archivo NVARCHAR(260) NOT NULL,
    hash_archivo VARBINARY(64) NULL,
    fecha_carga DATETIME2(0) NOT NULL CONSTRAINT DF_carga_fecha DEFAULT (SYSUTCDATETIME()),
    registros_leidos INT NOT NULL CONSTRAINT DF_carga_leidos DEFAULT (0),
    registros_validos INT NOT NULL CONSTRAINT DF_carga_validos DEFAULT (0),
    estatus VARCHAR(15) NOT NULL CONSTRAINT DF_carga_estatus DEFAULT ('PROCESANDO'),
    mensaje_error NVARCHAR(1000) NULL,
    CONSTRAINT CK_carga_estatus CHECK (estatus IN ('PROCESANDO', 'COMPLETADA', 'ERROR')),
    CONSTRAINT FK_carga_usuario FOREIGN KEY (usuario_id) REFERENCES dbo.usuario(usuario_id)
);

/* Filas originales de la primera hoja "Importación". Se conservan para trazabilidad
   y para que el procesador pueda mapearlas posteriormente a pedimentos y mercancias. */
CREATE TABLE dbo.carga_registro (
    carga_registro_id BIGINT IDENTITY(1,1) CONSTRAINT PK_carga_registro PRIMARY KEY,
    carga_id BIGINT NOT NULL,
    modulo VARCHAR(20) NOT NULL,
    numero_fila INT NOT NULL,
    datos_json NVARCHAR(MAX) NOT NULL,
    fecha_registro DATETIME2(0) NOT NULL CONSTRAINT DF_carga_registro_fecha DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT CK_carga_registro_modulo CHECK (modulo IN ('CAMARON', 'HIDROCARBURO', 'AZUCAR')),
    CONSTRAINT CK_carga_registro_json CHECK (ISJSON(datos_json) = 1),
    CONSTRAINT UQ_carga_registro_fila UNIQUE (carga_id, numero_fila),
    CONSTRAINT FK_carga_registro_carga FOREIGN KEY (carga_id) REFERENCES dbo.carga_archivo(carga_id)
);


/* Avisos programados por el administrador: INFORMATIVO (ventana que se puede cerrar) o
   MANTENIMIENTO (bloquea el sistema a quien no sea ADMIN mientras está vigente). Fechas en UTC.
*/
CREATE TABLE dbo.aviso (
    aviso_id INT IDENTITY(1,1) CONSTRAINT PK_aviso PRIMARY KEY,
    tipo VARCHAR(15) NOT NULL CONSTRAINT CK_aviso_tipo CHECK (tipo IN ('INFORMATIVO', 'MANTENIMIENTO')),
    titulo NVARCHAR(150) NOT NULL,
    mensaje NVARCHAR(1000) NOT NULL,
    fecha_inicio DATETIME2(0) NOT NULL,
    fecha_fin DATETIME2(0) NOT NULL,
    activo BIT NOT NULL CONSTRAINT DF_aviso_activo DEFAULT (1),
    creado_por INT NULL CONSTRAINT FK_aviso_usuario FOREIGN KEY REFERENCES dbo.usuario(usuario_id),
    fecha_creacion DATETIME2(0) NOT NULL CONSTRAINT DF_aviso_fecha DEFAULT (SYSUTCDATETIME()),
    CONSTRAINT CK_aviso_periodo CHECK (fecha_fin > fecha_inicio)
);

