-- ============================================================================
-- SCRIPT 03: Procedimientos Almacenados de Automatización
-- ============================================================================
-- Descripción: Automatiza la ingesta y validación de datos con TRY/CATCH
-- Autor: Equipo CIIN1021P
-- Fecha: 2026-09-26
-- ============================================================================

USE DataSaludPeru;
GO

-- ============================================================================
-- PROCEDIMIENTO 1: usp_InsertarAtencionesConValidacion
-- Propósito: Ingesta de datos de atenciones con control de calidad
-- Parámetros: @FechaAtención, @Establecimiento, @Region, @Sexo, @GrupoEdad, @PlanSeguro
-- Control de excepciones: TRY/CATCH, COMMIT/ROLLBACK
-- ============================================================================

IF OBJECT_ID('prod.usp_InsertarAtencionesConValidacion', 'P') IS NOT NULL
    DROP PROCEDURE prod.usp_InsertarAtencionesConValidacion;
GO

CREATE PROCEDURE prod.usp_InsertarAtencionesConValidacion
    @FechaAtención DATE,
    @EstablecimientoID NVARCHAR(50),
    @Establecimiento NVARCHAR(255),
    @Region NVARCHAR(100),
    @Provincia NVARCHAR(100),
    @Distrito NVARCHAR(100),
    @Sexo CHAR(1),
    @GrupoEdad NVARCHAR(50),
    @PlanSeguro NVARCHAR(100),
    @MensajeResultado NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @RegistrosInsertados INT = 0;
    DECLARE @RegistrosRechazados INT = 0;
    
    BEGIN TRY
        BEGIN TRANSACTION
        
        -- Validación 1: Fecha no puede ser en el futuro
        IF @FechaAtención > CAST(GETDATE() AS DATE)
        BEGIN
            SET @MensajeResultado = 'ERROR: Fecha de atención no puede ser en el futuro.';
            ROLLBACK TRANSACTION;
            RETURN 1;
        END
        
        -- Validación 2: Campos críticos no pueden estar vacíos
        IF @EstablecimientoID IS NULL OR @Region IS NULL
        BEGIN
            SET @MensajeResultado = 'ERROR: Campos críticos (EstablecimientoID, Region) no pueden ser NULL.';
            ROLLBACK TRANSACTION;
            RETURN 1;
        END
        
        -- Validación 3: Sexo debe ser 'M' o 'F'
        IF @Sexo IS NOT NULL AND @Sexo NOT IN ('M', 'F')
        BEGIN
            SET @MensajeResultado = 'ERROR: Sexo debe ser M o F.';
            ROLLBACK TRANSACTION;
            RETURN 1;
        END
        
        -- Validación 4: Verificar duplicado
        IF EXISTS (SELECT 1 FROM prod.SIS_Atenciones 
                   WHERE FechaAtención = @FechaAtención 
                   AND EstablecimientoID = @EstablecimientoID)
        BEGIN
            -- UPSERT: Actualizar si existe
            UPDATE prod.SIS_Atenciones
            SET Sexo = @Sexo,
                GrupoEdad = @GrupoEdad,
                PlanSeguro = @PlanSeguro,
                FechaRegistro = GETDATE()
            WHERE FechaAtención = @FechaAtención 
            AND EstablecimientoID = @EstablecimientoID;
            
            SET @RegistrosInsertados = @@ROWCOUNT;
            SET @MensajeResultado = 'ACTUALIZADO: ' + CAST(@RegistrosInsertados AS VARCHAR) + ' registro(s) actualizado(s).';
        END
        ELSE
        BEGIN
            -- INSERT: Nuevo registro
            INSERT INTO prod.SIS_Atenciones (
                FechaAtención, EstablecimientoID, Establecimiento, Region, Provincia, 
                Distrito, Sexo, GrupoEdad, PlanSeguro, Estado
            )
            VALUES (
                @FechaAtención, @EstablecimientoID, @Establecimiento, @Region, @Provincia,
                @Distrito, @Sexo, @GrupoEdad, @PlanSeguro, 'ACTIVO'
            );
            
            SET @RegistrosInsertados = @@ROWCOUNT;
            SET @MensajeResultado = 'INSERTADO: ' + CAST(@RegistrosInsertados AS VARCHAR) + ' nuevo(s) registro(s).';
        END
        
        COMMIT TRANSACTION;
        RETURN 0;
        
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        SET @MensajeResultado = 'ERROR SQL: ' + ERROR_MESSAGE();
        RETURN 1;
    END CATCH
END
GO

-- ============================================================================
-- PROCEDIMIENTO 2: usp_LimpiarDuplicados
-- Propósito: Identificar y limpiar registros duplicados
-- ============================================================================

IF OBJECT_ID('prod.usp_LimpiarDuplicados', 'P') IS NOT NULL
    DROP PROCEDURE prod.usp_LimpiarDuplicados;
GO

CREATE PROCEDURE prod.usp_LimpiarDuplicados
    @RegistrosCleaned INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @TotalBefore INT;
    DECLARE @TotalAfter INT;
    
    BEGIN TRY
        BEGIN TRANSACTION
        
        SELECT @TotalBefore = COUNT(*) FROM prod.SIS_Atenciones;
        
        -- Usar CTE para identificar duplicados
        ;WITH CTE_Duplicados AS (
            SELECT AtenciónID, 
                   ROW_NUMBER() OVER (PARTITION BY FechaAtención, EstablecimientoID ORDER BY AtenciónID DESC) AS RN
            FROM prod.SIS_Atenciones
        )
        DELETE FROM prod.SIS_Atenciones
        WHERE AtenciónID IN (
            SELECT AtenciónID FROM CTE_Duplicados WHERE RN > 1
        );
        
        SELECT @TotalAfter = COUNT(*) FROM prod.SIS_Atenciones;
        SET @RegistrosCleaned = @TotalBefore - @TotalAfter;
        
        COMMIT TRANSACTION;
        PRINT CONCAT('Duplicados eliminados: ', @RegistrosCleaned);
        
    END TRY
    BEGIN CATCH
        ROLLBACK TRANSACTION;
        PRINT 'ERROR en limpieza de duplicados: ' + ERROR_MESSAGE();
    END CATCH
END
GO

PRINT 'Procedimientos almacenados creados exitosamente.';
GO
