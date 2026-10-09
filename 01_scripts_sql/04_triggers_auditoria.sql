-- ============================================================================
-- SCRIPT 04: Triggers de Auditoría e Integridad
-- ============================================================================
-- Descripción: Triggers para registrar cambios y garantizar integridad de datos
-- Autor: Equipo CIIN1021P
-- Fecha: 2026-09-26
-- ============================================================================

USE DataSaludPeru;
GO

-- ============================================================================
-- TRIGGER 1: TR_Atenciones_Auditoria
-- Propósito: Registrar INSERT, UPDATE, DELETE en tabla de atenciones
-- ============================================================================

IF OBJECT_ID('prod.TR_Atenciones_Auditoria', 'TR') IS NOT NULL
    DROP TRIGGER prod.TR_Atenciones_Auditoria;
GO

CREATE TRIGGER prod.TR_Atenciones_Auditoria
ON prod.SIS_Atenciones
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Operación NVARCHAR(10);
    DECLARE @RowsAffected INT = @@ROWCOUNT;
    
    -- Determinar tipo de operación
    IF EXISTS(SELECT * FROM inserted) AND EXISTS(SELECT * FROM deleted)
        SET @Operación = 'UPDATE'
    ELSE IF EXISTS(SELECT * FROM inserted)
        SET @Operación = 'INSERT'
    ELSE IF EXISTS(SELECT * FROM deleted)
        SET @Operación = 'DELETE'
    
    BEGIN TRY
        -- Registrar en tabla de auditoría
        INSERT INTO audit.LOG_Auditoría (
            Tabla, Operación, RegistroID, UsuarioSQL, DatosNuevos, 
            IPEquipo, Descripción
        )
        SELECT 
            'SIS_Atenciones',
            @Operación,
            CAST(i.AtenciónID AS NVARCHAR(100)),
            SYSTEM_USER,
            (SELECT * FROM inserted i2 WHERE i2.AtenciónID = i.AtenciónID FOR JSON PATH, INCLUDE_NULL_VALUES),
            HOST_NAME(),
            CONCAT('Cambio en atención ID: ', i.AtenciónID, ' | Región: ', i.Region)
        FROM inserted i
        WHERE i.Estado IS NOT NULL  -- Filtro de ejemplo
        
        UNION ALL
        
        SELECT
            'SIS_Atenciones',
            @Operación,
            CAST(d.AtenciónID AS NVARCHAR(100)),
            SYSTEM_USER,
            (SELECT * FROM deleted d2 WHERE d2.AtenciónID = d.AtenciónID FOR JSON PATH, INCLUDE_NULL_VALUES),
            HOST_NAME(),
            CONCAT('Eliminación de atención ID: ', d.AtenciónID)
        FROM deleted d
        WHERE @Operación = 'DELETE';
        
    END TRY
    BEGIN CATCH
        -- Registrar errores sin afectar operación original
        INSERT INTO audit.LOG_Auditoría (
            Tabla, Operación, UsuarioSQL, Descripción
        )
        VALUES (
            'SIS_Atenciones',
            'ERROR_TRIGGER',
            SYSTEM_USER,
            'Error en TR_Atenciones_Auditoria: ' + ERROR_MESSAGE()
        );
    END CATCH
END
GO

-- ============================================================================
-- TRIGGER 2: TR_Atenciones_ValidarIntegridad
-- Propósito: Validar reglas de negocio antes de cambios
-- ============================================================================

IF OBJECT_ID('prod.TR_Atenciones_ValidarIntegridad', 'TR') IS NOT NULL
    DROP TRIGGER prod.TR_Atenciones_ValidarIntegridad;
GO

CREATE TRIGGER prod.TR_Atenciones_ValidarIntegridad
ON prod.SIS_Atenciones
INSTEAD OF INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @MensajeError NVARCHAR(500);
    
    -- Validar que no haya NULLs en campos críticos
    IF EXISTS(SELECT 1 FROM inserted WHERE EstablecimientoID IS NULL OR Region IS NULL)
    BEGIN
        SET @MensajeError = 'ERROR: No se permiten valores NULL en EstablecimientoID o Region.';
        RAISERROR(@MensajeError, 16, 1);
        RETURN;
    END
    
    -- Validar que fechas sean válidas
    IF EXISTS(SELECT 1 FROM inserted WHERE FechaAtención > CAST(GETDATE() AS DATE))
    BEGIN
        SET @MensajeError = 'ERROR: Fecha de atención no puede ser en el futuro.';
        RAISERROR(@MensajeError, 16, 1);
        RETURN;
    END
    
    -- Si todas las validaciones pasaron, ejecutar INSERT/UPDATE
    BEGIN TRY
        -- INSERT
        INSERT INTO prod.SIS_Atenciones (
            FechaAtención, EstablecimientoID, Establecimiento, Region, Provincia,
            Distrito, Sexo, GrupoEdad, PlanSeguro, Estado, FechaRegistro
        )
        SELECT
            FechaAtención, EstablecimientoID, Establecimiento, Region, Provincia,
            Distrito, Sexo, GrupoEdad, PlanSeguro, Estado, FechaRegistro
        FROM inserted;
    END TRY
    BEGIN CATCH
        SET @MensajeError = 'Error al insertar datos: ' + ERROR_MESSAGE();
        RAISERROR(@MensajeError, 16, 1);
    END CATCH
END
GO

-- ============================================================================
-- TRIGGER 3: TR_Afiliados_Auditoria (Análogo para tabla de afiliados)
-- ============================================================================

IF OBJECT_ID('prod.TR_Afiliados_Auditoria', 'TR') IS NOT NULL
    DROP TRIGGER prod.TR_Afiliados_Auditoria;
GO

CREATE TRIGGER prod.TR_Afiliados_Auditoria
ON prod.SIS_Afiliados
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @Operación NVARCHAR(10);
    
    IF EXISTS(SELECT * FROM inserted) AND EXISTS(SELECT * FROM deleted)
        SET @Operación = 'UPDATE'
    ELSE IF EXISTS(SELECT * FROM inserted)
        SET @Operación = 'INSERT'
    ELSE
        SET @Operación = 'DELETE'
    
    INSERT INTO audit.LOG_Auditoría (
        Tabla, Operación, RegistroID, UsuarioSQL, Descripción
    )
    SELECT 
        'SIS_Afiliados',
        @Operación,
        CódigoAfiliado,
        SYSTEM_USER,
        CONCAT('Afiliado: ', Nombre, ' | Plan: ', PlanSeguro)
    FROM inserted
    UNION ALL
    SELECT
        'SIS_Afiliados',
        @Operación,
        CódigoAfiliado,
        SYSTEM_USER,
        CONCAT('Eliminado afiliado: ', Nombre)
    FROM deleted
    WHERE @Operación = 'DELETE';
END
GO

PRINT 'Triggers de auditoría creados exitosamente.';
GO
