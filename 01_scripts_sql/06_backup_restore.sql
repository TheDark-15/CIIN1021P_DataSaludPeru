-- ============================================================================
-- SCRIPT 06: Política de Backup y Restore
-- ============================================================================
-- Descripción: Implementa estrategia FULL + DIFFERENTIAL
-- Cumplimiento: Ley N.° 29733, Art. 20 (Medidas de seguridad)
-- Autor: Equipo CIIN1021P
-- Fecha: 2026-09-26
-- ============================================================================

USE master;
GO

-- ============================================================================
-- BACKUP FULL: Copia completa de la base de datos (semanal)
-- ============================================================================

-- Ruta de backup (cambiar según tu sistema)
DECLARE @BackupPath NVARCHAR(500) = 'D:\Backups\DataSaludPeru\';
DECLARE @BackupFileName NVARCHAR(500);
DECLARE @FechaBackup NVARCHAR(20);

SET @FechaBackup = FORMAT(GETDATE(), 'yyyyMMdd_HHmmss');
SET @BackupFileName = @BackupPath + 'DataSaludPeru_FULL_' + @FechaBackup + '.bak';

PRINT 'Iniciando BACKUP FULL...';
PRINT 'Archivo: ' + @BackupFileName;

BEGIN TRY
    BACKUP DATABASE DataSaludPeru 
    TO DISK = @BackupFileName
    WITH 
        DESCRIPTION = 'Backup completo de DataSaludPeru',
        STATS = 10,
        COMPRESSION;
    
    PRINT 'BACKUP FULL completado exitosamente.';
    
    -- Registrar backup en tabla de auditoría
    INSERT INTO DataSaludPeru.audit.BackupPolicy (
        TipoBackup, ÚltimaEjecución, EstadoÚltimo, DescripciónÚltimo
    )
    VALUES ('FULL', GETDATE(), 'OK', 'Backup completado: ' + @BackupFileName);
    
END TRY
BEGIN CATCH
    PRINT 'ERROR en BACKUP FULL: ' + ERROR_MESSAGE();
    INSERT INTO DataSaludPeru.audit.BackupPolicy (
        TipoBackup, ÚltimaEjecución, EstadoÚltimo, DescripciónÚltimo
    )
    VALUES ('FULL', GETDATE(), 'ERROR', ERROR_MESSAGE());
END CATCH

GO

-- ============================================================================
-- BACKUP DIFFERENTIAL: Cambios desde último FULL (diario)
-- ============================================================================

DECLARE @BackupPathDiff NVARCHAR(500) = 'D:\Backups\DataSaludPeru\Differential\';
DECLARE @BackupFileNameDiff NVARCHAR(500);
DECLARE @FechaBackupDiff NVARCHAR(20);

SET @FechaBackupDiff = FORMAT(GETDATE(), 'yyyyMMdd_HHmmss');
SET @BackupFileNameDiff = @BackupPathDiff + 'DataSaludPeru_DIFF_' + @FechaBackupDiff + '.bak';

PRINT 'Iniciando BACKUP DIFFERENTIAL...';
PRINT 'Archivo: ' + @BackupFileNameDiff;

BEGIN TRY
    BACKUP DATABASE DataSaludPeru 
    TO DISK = @BackupFileNameDiff
    WITH 
        DESCRIPTION = 'Backup incremental de DataSaludPeru',
        DIFFERENTIAL,
        STATS = 10,
        COMPRESSION;
    
    PRINT 'BACKUP DIFFERENTIAL completado exitosamente.';
    
    INSERT INTO DataSaludPeru.audit.BackupPolicy (
        TipoBackup, ÚltimaEjecución, EstadoÚltimo, DescripciónÚltimo
    )
    VALUES ('DIFFERENTIAL', GETDATE(), 'OK', 'Backup diferencial completado: ' + @BackupFileNameDiff);
    
END TRY
BEGIN CATCH
    PRINT 'ERROR en BACKUP DIFFERENTIAL: ' + ERROR_MESSAGE();
    INSERT INTO DataSaludPeru.audit.BackupPolicy (
        TipoBackup, ÚltimaEjecución, EstadoÚltimo, DescripciónÚltimo
    )
    VALUES ('DIFFERENTIAL', GETDATE(), 'ERROR', ERROR_MESSAGE());
END CATCH

GO

-- ============================================================================
-- RESTORE (Prueba): Restaurar desde backup completo
-- NOTA: Ejecutar SOLO en entorno de recuperación, NO en producción
-- ============================================================================

/*
-- DESCOMENTAR SOLO PARA PRUEBAS DE RECUPERACIÓN

USE master;
GO

-- Paso 1: Poner base de datos en modo SINGLE_USER
ALTER DATABASE DataSaludPeru SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

-- Paso 2: Restaurar desde backup completo
RESTORE DATABASE DataSaludPeru 
FROM DISK = 'D:\Backups\DataSaludPeru\DataSaludPeru_FULL_20260926_120000.bak'
WITH 
    REPLACE,
    STATS = 10;

-- Paso 3: Restaurar cambios desde backup diferencial (opcional)
RESTORE DATABASE DataSaludPeru 
FROM DISK = 'D:\Backups\DataSaludPeru\Differential\DataSaludPeru_DIFF_20260926_180000.bak'
WITH 
    NORECOVERY;

-- Paso 4: Recuperar base de datos
RESTORE DATABASE DataSaludPeru WITH RECOVERY;

-- Paso 5: Volver a modo MULTI_USER
ALTER DATABASE DataSaludPeru SET MULTI_USER;

PRINT 'Restauración completada.';

*/

GO

-- ============================================================================
-- VERIFICAR INTEGRIDAD DE BACKUPS
-- ============================================================================

PRINT '========================================';
PRINT 'VERIFICACIÓN DE INTEGRIDAD DE BACKUPS';
PRINT '========================================';

-- Listar últimos backups realizados
SELECT 
    backup_set_id,
    database_name,
    type,
    backup_start_date,
    backup_finish_date,
    DATEDIFF(MINUTE, backup_start_date, backup_finish_date) AS DuraciónMinutos,
    backup_size,
    compressed_backup_size
FROM msdb.dbo.backupset
WHERE database_name = 'DataSaludPeru'
ORDER BY backup_start_date DESC;

PRINT 'Backups registrados exitosamente.';
GO
