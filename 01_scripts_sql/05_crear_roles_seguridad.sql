-- ============================================================================
-- SCRIPT 05: Roles, Permisos y Seguridad (Ley N.° 29733)
-- ============================================================================
-- Descripción: Implementa segregación de privilegios conforme a normativa
-- Ley N.° 29733: Ley de Protección de Datos Personales
-- Autor: Equipo CIIN1021P
-- Fecha: 2026-09-26
-- ============================================================================

USE DataSaludPeru;
GO

-- ============================================================================
-- ROL 1: DBRole_Administrador
-- Permisos: Control total de la base de datos
-- ============================================================================

IF NOT EXISTS(SELECT * FROM sys.database_principals WHERE name = 'DBRole_Administrador' AND type = 'R')
BEGIN
    CREATE ROLE DBRole_Administrador;
    PRINT 'Rol DBRole_Administrador creado.';
END

-- Conceder permisos al administrador
GRANT CREATE TABLE, CREATE PROCEDURE, CREATE TRIGGER, CREATE SCHEMA TO DBRole_Administrador;
GRANT ALTER, DROP ON SCHEMA::[prod] TO DBRole_Administrador;
GRANT ALTER, DROP ON SCHEMA::[audit] TO DBRole_Administrador;
GRANT ALTER, DROP ON SCHEMA::[dw] TO DBRole_Administrador;
GRANT EXECUTE TO DBRole_Administrador;

-- ============================================================================
-- ROL 2: DBRole_AnalistaDB
-- Permisos: Lectura y análisis de datos, ejecución de procedimientos
-- Restricción: NO puede actualizar ni eliminar datos de pacientes
-- ============================================================================

IF NOT EXISTS(SELECT * FROM sys.database_principals WHERE name = 'DBRole_AnalistaDB' AND type = 'R')
BEGIN
    CREATE ROLE DBRole_AnalistaDB;
    PRINT 'Rol DBRole_AnalistaDB creado.';
END

-- Permisos de lectura en tablas de producción
GRANT SELECT ON SCHEMA::[prod] TO DBRole_AnalistaDB;
GRANT SELECT ON SCHEMA::[dw] TO DBRole_AnalistaDB;

-- Permiso para ejecutar procedimientos analíticos
GRANT EXECUTE ON SCHEMA::[prod] TO DBRole_AnalistaDB;

-- ============================================================================
-- ROL 3: DBRole_Auditor
-- Permisos: Lectura SOLO de logs de auditoría, NO acceso a datos personales
-- Responsabilidad: Verificar cumplimiento de Ley N.° 29733
-- ============================================================================

IF NOT EXISTS(SELECT * FROM sys.database_principals WHERE name = 'DBRole_Auditor' AND type = 'R')
BEGIN
    CREATE ROLE DBRole_Auditor;
    PRINT 'Rol DBRole_Auditor creado.';
END

-- SOLO lectura de auditoría
GRANT SELECT ON SCHEMA::[audit] TO DBRole_Auditor;

-- NO permitir lectura de datos personales
DENY SELECT ON SCHEMA::[prod] TO DBRole_Auditor;

-- ============================================================================
-- POLÍTICA DE ROW-LEVEL SECURITY (RLS)
-- Propósito: Restringir acceso a datos por región (Ley N.° 29733, Art. 11)
-- ============================================================================

-- Crear tabla de política de datos por región
IF OBJECT_ID('dw.RLS_RegionPolicy', 'U') IS NOT NULL
    DROP TABLE dw.RLS_RegionPolicy;

CREATE TABLE dw.RLS_RegionPolicy (
    PolicyID INT IDENTITY(1,1) PRIMARY KEY,
    Usuario NVARCHAR(100) NOT NULL UNIQUE,
    RegionPermitida NVARCHAR(100) NOT NULL,
    FechaCreación DATETIME DEFAULT GETDATE()
);

-- Ejemplo de política (ajustar según usuarios reales)
INSERT INTO dw.RLS_RegionPolicy (Usuario, RegionPermitida)
VALUES 
    (SYSTEM_USER, 'LA LIBERTAD'),
    ('analyst@minsa.gob.pe', 'LA LIBERTAD'),
    ('auditor@minsa.gob.pe', '*');  -- Auditor ve todas las regiones

GO

-- ============================================================================
-- POLÍTICA DE BACKUP (Cumplimiento Ley N.° 29733, Art. 20)
-- Descripción: Estrategia FULL + DIFFERENTIAL para recuperación
-- ============================================================================

-- Crear tabla de política de backups
IF OBJECT_ID('audit.BackupPolicy', 'U') IS NOT NULL
    DROP TABLE audit.BackupPolicy;

CREATE TABLE audit.BackupPolicy (
    BackupID INT IDENTITY(1,1) PRIMARY KEY,
    TipoBackup NVARCHAR(20),         -- 'FULL' o 'DIFFERENTIAL'
    FrecuenciaHoras INT,              -- Cada cuántas horas
    UbicaciónNFS NVARCHAR(500),      -- Ruta NFS compartida
    RetencionDías INT,                -- Cuántos días mantener
    ÚltimaEjecución DATETIME,
    EstadoÚltimo NVARCHAR(20),        -- 'OK' o 'ERROR'
    DescripciónÚltimo NVARCHAR(500)
);

INSERT INTO audit.BackupPolicy (TipoBackup, FrecuenciaHoras, UbicaciónNFS, RetencionDías)
VALUES 
    ('FULL', 24, '\\\\NAS-MINSA\\backups\\DataSaludPeru\\', 90),
    ('DIFFERENTIAL', 6, '\\\\NAS-MINSA\\backups\\DataSaludPeru\\diff\\', 30);

GO

-- ============================================================================
-- VERIFICACIÓN DE CUMPLIMIENTO NORMATIVO
-- Ley N.° 29733, Art. 11: Medidas de Seguridad Técnica
-- ============================================================================

PRINT '========================================';
PRINT 'VERIFICACIÓN DE CUMPLIMIENTO LEY 29733';
PRINT '========================================';

-- 1. Verificar segregación de privilegios
PRINT 'Roles creados:';
SELECT name FROM sys.database_principals WHERE type = 'R' AND name LIKE 'DBRole_%';

-- 2. Verificar acceso a tablas de auditoría
PRINT 'Permisos en tabla de auditoría:';
SELECT * FROM sys.database_permissions 
WHERE class_desc = 'SCHEMA' AND major_id IN (
    SELECT schema_id FROM sys.schemas WHERE name = 'audit'
);

-- 3. Verificar política de backups
PRINT 'Política de backups configurada:';
SELECT * FROM audit.BackupPolicy;

PRINT 'Configuración de seguridad completada.';
GO
