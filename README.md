# DataSalud Perú

## Proyecto integrador — Bases de Datos Avanzadas y Big Data

### 1. Descripción

DataSalud Perú es un proyecto orientado al análisis de información abierta del Seguro Integral de Salud (SIS), con énfasis en la cobertura de afiliados y la utilización de servicios de salud en la región La Libertad.

### 2. Objetivos

* Implementar una base de datos relacional en SQL Server.
* Aplicar automatización, transacciones, auditoría y seguridad mediante T-SQL.
* Explorar operaciones CRUD y agregaciones con MongoDB.
* Construir un Data Warehouse dimensional siguiendo la metodología Kimball.
* Implementar procesos ETL con trazabilidad.
* Preparar análisis BI y pruebas de procesamiento con Apache Spark.

### 3. Fuentes de datos

Se utilizan conjuntos de datos abiertos del SIS sobre afiliados activos y atenciones. En el informe se documentan las fuentes, los periodos, los esquemas y los problemas de calidad identificados.

### 4. Estructura del repositorio

* `01_SQL_Server`: scripts de creación, carga, automatización y seguridad.
* `02_MongoDB`: colecciones, operaciones CRUD, consultas e índices.
* `03_DataWarehouse_ETL`: modelo dimensional, DDL y procesos ETL.
* `04_PowerBI`: reportes y evidencias BI.
* `05_Spark`: scripts, notebooks y resultados de pruebas.
* `06_Documentacion`: informe, diagramas y evidencias.

### 5. Requisitos

* Microsoft SQL Server y SQL Server Management Studio.
* MongoDB Community Server o MongoDB Compass.
* Power BI Desktop para la etapa BI.
* Python y PySpark para la etapa Big Data, según las instrucciones de cada script.

### 6. Orden de ejecución

1. Revisar las fuentes y los requisitos de cada etapa.
2. Ejecutar los scripts de SQL Server en el orden indicado.
3. Ejecutar los scripts de MongoDB.
4. Crear y cargar las dimensiones y la tabla de hechos del Data Warehouse.
5. Ejecutar y validar el proceso ETL.
6. Configurar BI y ejecutar las pruebas Spark cuando sus scripts estén disponibles.

### 7. Trazabilidad

Cada etapa debe documentar su fuente, script ejecutado, fecha, cantidad de registros procesados y resultado.

### 8. Seguridad

No se publican credenciales, contraseñas, cadenas de conexión con secretos, datos personales ni copias de seguridad de la base de datos. Los archivos publicados deben revisarse antes de subirlos.

### 9. Estado del proyecto

El estado de cada componente se documentará según su implementación y evidencia de ejecución real. Los componentes pendientes no se presentan como terminados.
