-- ============================================================================
-- SCRIPT 01: Crear Base de Datos DataSaludPeru
-- ============================================================================
-- Descripción: Crea la base de datos principal del proyecto
-- Autor: Equipo CIIN1021P
-- Fecha: 2026-09-25
-- ============================================================================

-- Validar si la base de datos existe
IF DB_ID('DataSaludPeru') IS NULL
BEGIN
    CREATE DATABASE DataSaludPeru;
    PRINT 'Base de datos DataSaludPeru creada exitosamente.'
END
ELSE
BEGIN
    PRINT 'Base de datos DataSaludPeru ya existe.'
END
GO

-- Cambiar contexto a la nueva base de datos
USE DataSaludPeru;
GO

-- Crear esquema para tablas de producción
IF SCHEMA_ID('prod') IS NULL
BEGIN
    CREATE SCHEMA prod AUTHORIZATION dbo;
    PRINT 'Esquema prod creado.'
END
GO

-- Crear esquema para tablas de auditoría
IF SCHEMA_ID('audit') IS NULL
BEGIN
    CREATE SCHEMA audit AUTHORIZATION dbo;
    PRINT 'Esquema audit creado.'
END
GO

-- Crear esquema para tablas de dimensión (Data Warehouse)
IF SCHEMA_ID('dw') IS NULL
BEGIN
    CREATE SCHEMA dw AUTHORIZATION dbo;
    PRINT 'Esquema dw creado.'
END
GO

PRINT '========================================';
PRINT 'Infraestructura de base de datos lista';
PRINT '========================================';
