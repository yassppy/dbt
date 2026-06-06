# DBT

## ¿Cual era el probema y como llego a dbt sea la solucción?

Antes de dbt, transformar datos era trabajo exclusivo de ingenieros con conocimientos de SQL avanzado y acceso directo a los pipelines. Los analistas dependían de ellos para cualquier cambio, lo que generaba cuellos de botella.
dbt nació para resolver eso: permite definir transformaciones directamente en SQL, con control de versiones, pruebas y documentación incluida. El analista escribe SQL, dbt se encarga del resto.

## ¿Quienes pueden utilizar esto?

dbt está pensado principalmente para analistas e ingenieros de analytics, no tanto para científicos de datos. La distinción es importante:

- Analista de datos / Analytics Engineer → trabaja con dbt para transformar y modelar datos listos para reportes y dashboards
- Ingeniero de datos → construye los pipelines que traen los datos crudos al warehouse, donde utiliza dbt para transformarlos
- Científico de datos → consume los datos ya transformados para modelos de ML y estadística, raramente toca dbt.

## ¿Qué es YAML?

YAML es un lenguaje de marcado de datos que se utiliza comúnmente en la configuración de aplicaciones. Es legible y fácil de escribir.

## DuckDB

Es una base de datos Open source sin servidor de código abierto como SQLite. Pero esto esta enfocado en la analítica y vectorizada siendo muy rápido y eficiente.

## Flujo de trabajo

### ✅ Primer paso crear el proyecto:
  - ``dbt init <project_name>`` -> Crea la raíz del proyecto y la estructura inicial
  - Nos va a perdir ingresar un número le ponemos ``1`` que es por defecto duckdb

### ✅ Segundo paso definir la configuración del archivo ``profiles.yml``:
  - Crear el archivo ``profiles.yml`` donde le vas a indicar type: duckdb es para local y type: snowflake es para producción.
  - ``dbt debug`` con esto vamos a comprobar la configuración si esta todo correcto.

  ```yaml
  nyc_yellow_taxi        #← nombre del perfil (debe coincidir con dbt_project.yml)
    outputs:
      dev:               #← nombre del entorno
        type: duckdb     #← motor
        path: dbt.duckdb #← archivo donde se guardan los datos
      prod:              #← podrías tener otro entorno (Snowflake, Postgres, etc.)
        type: snowflake
        ...
    target: dev          #← cuál entorno usar por defecto
  ```

### ✅ Tercer paso: Crear / Usar modelos / plantillas

Un **modelo en dbt** es una representación de las transformaciones de datos, escrita normalmente en SQL como un `SELECT`. Cada modelo es un archivo `.sql` dentro de la carpeta `models/`.

Un **data model** en general es el significado lógico de los datos: cómo se relacionan y cómo los entiende el equipo.

#### Parquet

Formato de archivo binario columnar, eficiente para almacenar y consultar grandes volúmenes de datos. DuckDB lo puede leer directamente de dos formas:

```sql
SELECT * FROM read_parquet('archivo.parquet')
-- o simplemente:
SELECT * FROM 'archivo.parquet'
```

#### Tabla vs Vista

| | Tabla | Vista |
|---|---|---|
| Almacena datos | ✅ Sí, ocupa espacio | ❌ No, es virtual |
| Se actualiza | Solo cuando se regenera | En cada consulta |
| Creada por dbt | ✅ | ✅ |

#### Actualizar modelos

Se actualiza un modelo cuando:
- Los requisitos cambian o no estaban completos.
- Hay bugs en las consultas.
- Se migra a otra fuente o destino de datos.

El flujo de actualización es:
1. Obtener la última versión del proyecto (`git clone` o `git pull`)
2. Localizar el modelo a modificar
3. Editar el archivo `.sql`
4. Regenerar con `dbt run` o `dbt run -f` para forzar actualización completa
5. Guardar cambios en control de versiones

#### Archivos YAML relevantes

- `dbt_project.yml` → configuración global del proyecto (nombre, rutas, materialización por defecto). Solo hay uno por proyecto.
- `model_properties.yml` → propiedades de cada modelo (descripción, documentación). Puede haber varios y llamarse de cualquier forma con extensión `.yml` dentro de `models/`.

### ✅ Cuarto paso Instanciar modelos:
- Se utiliza ``dbt run`` para ejecutar los modelos definidos en el proyecto. Ojo solo se debe utilizar cuando se haya hecho cambios en los modelos o cuando es necesario ejecutar los modelos desde cero.

### ✅ Quinto paso Verificar / Probar / Depurar:
- Se utiliza ``dbt test`` para ejecutar las pruebas definidas en el proyecto.

## Documentación, Jinja y modelos jerárquicos en dbt

### ¿Por qué documentar?

La documentación en dbt sirve para que otros miembros del equipo entiendan qué hace cada modelo, qué columnas tiene y de dónde vienen los datos. Se define en los archivos `.yml` dentro de `models/`:

```yaml
version: 2
models:
  - name: taxi_rides_raw
    description: Yellow Taxi raw data
    access: public
  - name: avg_fare_per_day
    description: Average ride per day
    access: public
```

#### Comandos de documentación

| Comando | Para qué sirve |
|---|---|
| `dbt docs generate` | Genera el sitio web de documentación (correr después de `dbt run`) |
| `dbt docs serve` | Abre la documentación en el navegador (solo para desarrollo local) |
| `dbt docs -h` | Muestra la ayuda de los subcomandos disponibles |

La documentación muestra los modelos, descripciones, columnas con tipos de datos, tests y el grafo de dependencias (lineage).

---

### Jinja en dbt

Jinja es un lenguaje de plantillas que permite escribir SQL más dinámico y reutilizable. En dbt se usa dentro de los archivos `.sql` con la sintaxis `{{ ... }}`.

**Ejemplo práctico** — en vez de repetir la misma función para cada columna:

```sql
-- Sin Jinja (repetitivo)
SELECT
  COALESCE(start_date, '2025-01-01') as start_date,
  COALESCE(update_date, '2025-01-01') as update_date,
  COALESCE(end_date, '2025-01-01') as end_date
FROM Events

-- Con Jinja (limpio)
SELECT
  {% for column in ['start_date', 'update_date', 'end_date'] %}
  COALESCE({{ column }}, '2025-01-01') as {{ column }}
  {% endfor %}
FROM Events
```

Funciones Jinja más usadas en dbt: `ref` (referenciar otro modelo), `config` (acceder a configuraciones), `docs` (acceder a documentación).

---

### Modelos jerárquicos y DAG

Cuando un modelo depende de otro, dbt necesita saber el orden de construcción. Eso se define con `{{ ref('nombre_modelo') }}` en el SQL:

```sql
-- En vez de poner el nombre directo de la tabla:
SELECT * FROM taxi_rides_raw

-- Se usa ref para declarar la dependencia:
SELECT * FROM {{ ref('taxi_rides_raw') }}
```

Esto genera automáticamente el **DAG** (Directed Acyclic Graph) o grafo de linaje — el mapa visual de qué modelo depende de cuál. dbt lo usa para construir los modelos en el orden correcto.

**Ejemplo:** si `avg_fare_per_day` usa `{{ ref('taxi_rides_raw') }}`, dbt construye `taxi_rides_raw` primero. Sin el `ref`, dbt ejecutaría en orden alfabético y `avg_fare_per_day` fallaría porque su fuente aún no existe.

## dbt – Guía de Nomenclatura (Best Practices)
 
> Fuente: DataCamp · *Case Study: Building E-Commerce Data Models with dbt*
> Referencia oficial: https://docs.getdbt.com/best-practices
 
---
 
## 📁 Estructura de nombres para modelos (`.sql`)
 
| Regla | Descripción |
|-------|-------------|
| Separador | Doble guión bajo `__` entre el nombre del origen y el nombre del modelo |
| Patrón | `<data_source>__<model_name>.sql` |
 
### Ejemplos
```
stg_looker__distribution_centers.sql
stg_looker__orders.sql
```
 
---
 
## 📄 Estructura de nombres para archivos YAML (`.yml`)
 
| Regla | Descripción |
|-------|-------------|
| Prefijo | Inicia con guión bajo simple `_` |
| Separador | Doble guión bajo `__` entre el nombre del origen y el tipo de artefacto |
| Patrón | `_<data_source>__<artifact_type>.yml` |
 
### Ejemplos
```
_looker__models.yml
_looker__sources.yml
```
 
---
 
## 📌 Resumen rápido
 
```
Modelos SQL  →  <origen>__<modelo>.sql       (doble __)
Archivos YML →  _<origen>__<artefacto>.yml   (_ inicial + doble __)
```
 
---
