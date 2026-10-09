-- ============================================================================
-- SCRIPT 02: Crear Tablas de Producción (Esquema PROD)
-- ============================================================================
-- Descripción: Define el esquema relacional para ingesta de datos del MINSA
-- Basado en: OPENDATA_DS_01_ATENCIONES + OPENDATA_AFILIADOS
-- Autor: Equipo CIIN1021P
-- Fecha: 2026-09-25
-- ============================================================================

USE DataSaludPeru;
GO

-- Tabla: SIS_Atenciones (Datos de atenciones ambulatorias)
IF OBJECT_ID('prod.SIS_Atenciones', 'U') IS NOT NULL
    DROP TABLE prod.SIS_Atenciones;

CREATE TABLE prod.SIS_Atenciones (
    AtenciónID          INT IDENTITY(1,1) PRIMARY KEY,
    FechaAtención       DATE NOT NULL,
    CodigoEstad         NVARCHAR(50),
    EstablecimientoID   NVARCHAR(50),
    Establecimiento     NVARCHAR(255),
    Region              NVARCHAR(100),
    Provincia           NVARCHAR(100),
    Distrito            NVARCHAR(100),
    CódigoIPRESS        NVARCHAR(50),
    Sexo                CHAR(1),  -- 'M' o 'F'
    GrupoEdad           NVARCHAR(50),
    Diagnóstico         NVARCHAR(500),
    PlanSeguro          NVARCHAR(100),
    FechaRegistro       DATETIME DEFAULT GETDATE(),
    Estado              NVARCHAR(20) DEFAULT 'ACTIVO',
    CONSTRAINT UK_AtenciónUnica UNIQUE (FechaAtención, EstablecimientoID)
);

-- Tabla: SIS_Afiliados (Datos de afiliados del sistema)
IF OBJECT_ID('prod.SIS_Afiliados', 'U') IS NOT NULL
    DROP TABLE prod.SIS_Afiliados;

CREATE TABLE prod.SIS_Afiliados (
    AfiliadoID          INT IDENTITY(1,1) PRIMARY KEY,
    CódigoAfiliado      NVARCHAR(50) UNIQUE NOT NULL,
    Nombre              NVARCHAR(255),
    FechaNacimiento     DATE,
    Sexo                CHAR(1),
    Dirección           NVARCHAR(500),
    Region              NVARCHAR(100),
    Provincia           NVARCHAR(100),
    Distrito            NVARCHAR(100),
    PlanSeguro          NVARCHAR(100),
    FechaAfiliación     DATE,
    FechaRegistro       DATETIME DEFAULT GETDATE(),
    Estado              NVARCHAR(20) DEFAULT 'ACTIVO'
);

-- Tabla: LOG_Auditoría (Para registrar cambios - usada por triggers)
IF OBJECT_ID('audit.LOG_Auditoría', 'U') IS NOT NULL
    DROP TABLE audit.LOG_Auditoría;

CREATE TABLE audit.LOG_Auditoría (
    LogID               INT IDENTITY(1,1) PRIMARY KEY,
    Tabla               NVARCHAR(100) NOT NULL,
    Operación           NVARCHAR(10) NOT NULL,  -- 'INSERT', 'UPDATE', 'DELETE'
    RegistroID          NVARCHAR(100),
    UsuarioSQL          NVARCHAR(100),
    FechaOperación      DATETIME DEFAULT GETDATE(),
    DatosAnteriores     NVARCHAR(MAX),
    DatosNuevos         NVARCHAR(MAX),
    IPEquipo            NVARCHAR(50),
    Descripción         NVARCHAR(500)
);

-- Crear índices para mejorar rendimiento
CREATE INDEX IX_Atenciones_Fecha ON prod.SIS_Atenciones(FechaAtención);
CREATE INDEX IX_Atenciones_Region ON prod.SIS_Atenciones(Region);
CREATE INDEX IX_Atenciones_PlanSeguro ON prod.SIS_Atenciones(PlanSeguro);
CREATE INDEX IX_Afiliados_PlanSeguro ON prod.SIS_Afiliados(PlanSeguro);
CREATE INDEX IX_Afiliados_Region ON prod.SIS_Afiliados(Region);

PRINT 'Tablas de producción creadas exitosamente.';
GO
