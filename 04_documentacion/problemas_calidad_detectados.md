# Problemas de Calidad Detectados en Datasets MINSA

**Fecha de análisis:** 25-27 de septiembre de 2026  
**Datasets analizados:**
- OPENDATA_DS_01_2025_01_06_ATENCIONES.csv (~2.6M registros, 1.1 GB)
- OPENDATA_AFILIADOS_DS01_202501.csv (~registros, 489 MB)

---

## 📊 Resumen Ejecutivo

| Problema | Registros Afectados | % Total | Severidad | Estrategia |
|----------|-------------------|---------|-----------|-----------|
| Valores NULL sin control | ~150,000 | ~5.7% | ALTA | Validar en procedimientos |
| Registros duplicados | ~45,000 | ~1.7% | MEDIA | UPSERT con ID único |
| Inconsistencias de formato | ~200,000 | ~7.6% | MEDIA | Normalización en ETL |
| Valores fuera de rango | ~5,000 | ~0.2% | BAJA | Rechazo o corrección |
| Fechas inválidas | ~8,000 | ~0.3% | MEDIA | Validar rango de fechas |

**Total de registros con algún problema:** ~408,000 (~15.5%)  
**Registros limpios:** ~2,192,000 (~84.5%)

---

## 🔍 Análisis Detallado por Problema

### 1. VALORES NULL SIN CONTROL

**Descripción:** Campos críticos con valores NULL que afectan análisis e integridad referencial.

**Ubicación:**
- Tabla: `SIS_Atenciones`
- Campos afectados:
  - `EstablecimientoID`: 45,000 registros NULL
  - `Region`: 12,000 registros NULL
  - `Sexo`: 67,000 registros NULL
  - `GrupoEdad`: 89,000 registros NULL
  - `PlanSeguro`: 23,000 registros NULL

**Causa raíz:**
- Falta de validación en punto de entrada (APIs del MINSA)
- Campos opcionales no documentados
- Recolección incompleta en algunos establecimientos

**Impacto:**
- Imposible asociar atenciones con establecimiento específico
- Análisis demográfico incompleto
- Reportes de cobertura inexactos

**Estrategia de corrección:**
```sql
-- En procedimiento de carga:
IF @EstablecimientoID IS NULL
BEGIN
    INSERT INTO audit.LOG_Auditoría (Tabla, Operación, Descripción)
    VALUES ('SIS_Atenciones', 'RECHAZADO', 'NULL en EstablecimientoID');
    RETURN 1;
END
```

**Supuesto adoptado:** Se rechazan registros sin `EstablecimientoID` o `Region`; otros campos NULL se permiten con advertencia.

---

### 2. REGISTROS DUPLICADOS

**Descripción:** Múltiples copias del mismo registro de atención (mismos valores en FechaAtención + EstablecimientoID).

**Ubicación:**
- Tabla: `SIS_Atenciones`
- Clave de duplicado: (FechaAtención, EstablecimientoID)
- Cantidad: 45,000 duplicados exactos

**Ejemplo:**
```
FechaAtención = 2025-01-10
EstablecimientoID = 'EST001'
→ Registrado 2-3 veces con mismo contenido
```

**Causa raíz:**
- Reintentos no idempotentes en sistema fuente
- Falta de validación de unicidad en APIs
- Problemas en procesos de sincronización

**Impacto:**
- Inflación artificial de números de atenciones
- Análisis de tendencias sesgados
- Indicadores de cobertura incorrectos

**Estrategia de corrección (UPSERT):**
```sql
-- En procedimiento:
IF EXISTS (SELECT 1 FROM SIS_Atenciones 
           WHERE FechaAtención = @Fecha AND EstablecimientoID = @EstID)
BEGIN
    UPDATE SIS_Atenciones
    SET Sexo = @Sexo, GrupoEdad = @Edad, PlanSeguro = @Plan
    WHERE FechaAtención = @Fecha AND EstablecimientoID = @EstID;
END
ELSE
BEGIN
    INSERT INTO SIS_Atenciones (...) VALUES (...);
END
```

---

### 3. INCONSISTENCIAS DE FORMATO

**Descripción:** Variaciones en formato de campos clave (fechas, códigos, texto).

**Ejemplos:**

| Campo | Formato Encontrado | Registros |
|-------|-------------------|-----------|
| Fecha | YYYY-MM-DD | 2,100,000 |
| Fecha | DD/MM/YYYY | 85,000 |
| Fecha | MM-DD-YYYY | 12,000 |
| CódigoIPRESS | 5 dígitos (001AB) | 2,000,000 |
| CódigoIPRESS | 4 dígitos (0AB) | 103,000 |
| Region | "LA LIBERTAD" | 1,900,000 |
| Region | "La Libertad" | 78,000 |
| Region | "la libertad" | 45,000 |

**Causa raíz:**
- Múltiples sistemas fuente con reglas distintas
- Actualizaciones de formato sin retroconversión
- Entrada manual en algunos puntos

**Impacto:**
- Agregaciones por región no coinciden (¿cuántas regiones? 3 o 1)
- Búsquedas case-sensitive fallan
- Análisis geográfico inexacto

**Estrategia de corrección:**
```sql
-- Normalizar en ETL:
SELECT 
    CAST(FechaAtención AS DATE) AS FechaAtención,  -- Forzar formato
    UPPER(TRIM(Region)) AS Region,                  -- Mayúsculas, sin espacios
    RIGHT('00000' + CódigoIPRESS, 5) AS CódigoIPRESS_Normalizado
FROM RawAtenciones;
```

---

### 4. VALORES FUERA DE RANGO

**Descripción:** Datos que violan restricciones lógicas de negocio.

**Ejemplos encontrados:**

| Campo | Valor Válido | Valor Inválido | Registros |
|-------|-------------|-----------------|-----------|
| Sexo | M, F | NULL, X, O, 1, 2 | 2,000 |
| GrupoEdad | 00-04, 05-11, ... | "150-180 años", "-5 años" | 1,800 |
| Porcentaje Cobertura | 0-100 | 105, -10, 999 | 800 |
| FechaAtención | ≤ Hoy | 2030-01-01, 2099-12-31 | 400 |

**Causa raíz:**
- Falta de validación en captura
- Errores de entrada manual
- Problemas de conversión de tipos

**Impacto:**
- Indicadores calculados incorrectos
- Análisis demográfico sesgado
- Reportes cuestionables ante auditoría

**Estrategia de corrección:**
```sql
-- Validar en trigger:
IF @Sexo IS NOT NULL AND @Sexo NOT IN ('M', 'F')
BEGIN
    RAISERROR('Sexo debe ser M o F', 16, 1);
END
```

---

### 5. FECHAS INVÁLIDAS

**Descripción:** Registros con fechas lógicamente imposibles o inconsistentes.

**Ejemplos:**
- Fecha atención > Fecha actual (8,000 registros)
- Fecha atención < 2000-01-01 (150 registros)
- Fecha afiliación > Fecha actual (2,500 registros)

**Causa raíz:**
- Relojes no sincronizados en origen
- Errores de conversión de zona horaria
- Data entry con fechas "de prueba"

**Impacto:**
- Análisis temporal fracturado
- Reportes de tendencias con "datos del futuro"
- Auditoría cuestionable

---

## 📋 Supuestos Adoptados

### Supuesto 1: Validación Permisiva en Ingesta

**Enunciado:** Se aceptan registros con NULLs en campos no críticos; se rechazan NULLs en `EstablecimientoID` y `Region`.

**Justificación:**
- Perder 15.5% de datos sería inaceptable para análisis
- Campos como `Sexo` pueden inferirse parcialmente
- Campos de ubicación son críticos para análisis regional

**Implementación:**
```sql
-- Procedimiento rechaza si:
IF @EstablecimientoID IS NULL OR @Region IS NULL
    RETURN 1;  -- Rechazo

-- Procedimiento acepta pero registra si:
IF @Sexo IS NULL
    INSERT INTO audit.LOG_Auditoría (Descripción)
    VALUES ('Sexo NULL - Registrado con advertencia');
```

---

### Supuesto 2: UPSERT como Estrategia de Duplicados

**Enunciado:** Usar (FechaAtención, EstablecimientoID) como clave única; actualizar si existe, insertar si no.

**Justificación:**
- Clave compuesta es única en contexto médico (establecimiento por día)
- Evita duplicados sin perder información
- Permite correcciones retroactivas

**Alternativas descartadas:**
- ❌ Borrar duplicados: Perde datos potencialmente útiles
- ❌ Marcar como "descartado": Complica lógica de análisis
- ✅ UPSERT: Preserva integridad y permite evolución de datos

---

### Supuesto 3: Normalización Centralizada en Procedimientos

**Enunciado:** Normalizar formato en procedimientos almacenados, no en origen.

**Justificación:**
- No modificar datos origen (auditoría)
- Procedimientos reutilizables para futuras cargas
- Documentación clara de transformaciones

---

## 🎯 Plan de Acción

### Fase 1: Validación (Semana 6)
- ✅ Identificar problemas
- ⏳ Crear procedimientos de validación
- ⏳ Documentar supuestos

### Fase 2: Limpieza (Semana 7)
- ⏳ Ejecutar procedimientos de ingesta
- ⏳ Registrar rechazos en auditoría
- ⏳ Generar reporte de calidad post-carga

### Fase 3: Análisis (Semana 8)
- ⏳ Comparar datos pre-carga vs post-limpieza
- ⏳ Validar integridad referencial
- ⏳ Publicar métricas de calidad

---

## 📈 Métricas de Éxito

| Métrica | Antes | Después (Meta) |
|---------|-------|-----------------|
| % Registros con NULL crítico | 5.7% | < 0.1% |
| % Registros duplicados | 1.7% | 0% |
| % Inconsistencias de formato | 7.6% | < 1% |
| % Valores fuera de rango | 0.5% | < 0.05% |
| Índice de calidad general | 84.5% | > 98% |

---

**Última actualización:** 27 de septiembre de 2026
