"""
=============================================================
  MIGRACIÓN AIRTABLE → SUPABASE (Paso a paso)
=============================================================
  Este script:
  1. Se conecta a tu base de Airtable
  2. Lee todas las tablas y sus registros
  3. Crea las tablas equivalentes en Supabase (PostgreSQL)
  4. Inserta todos los datos

  Requisitos:
    pip install pyairtable supabase python-dotenv
=============================================================
"""

import os
import json
import re
import time
from datetime import datetime
from dotenv import load_dotenv

# ─── PASO 0: Cargar variables de entorno ─────────────────────
# Creamos un archivo .env para no poner claves en el código
load_dotenv()

AIRTABLE_API_KEY = os.getenv("AIRTABLE_API_KEY")       # Tu Personal Access Token de Airtable
AIRTABLE_BASE_ID = os.getenv("AIRTABLE_BASE_ID")       # Empieza con "app..."
SUPABASE_URL = os.getenv("SUPABASE_URL")                # https://xxxxx.supabase.co
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY") # Service Role Key (no la anon key)

# Validar que tenemos todo configurado
missing = []
if not AIRTABLE_API_KEY:  missing.append("AIRTABLE_API_KEY")
if not AIRTABLE_BASE_ID:  missing.append("AIRTABLE_BASE_ID")
if not SUPABASE_URL:      missing.append("SUPABASE_URL")
if not SUPABASE_SERVICE_KEY: missing.append("SUPABASE_SERVICE_KEY")

if missing:
    print("❌ Faltan estas variables en tu archivo .env:")
    for var in missing:
        print(f"   - {var}")
    print("\n📄 Crea un archivo .env con el formato del archivo .env.example")
    exit(1)


# ─── PASO 1: Conectar a Airtable ─────────────────────────────
from pyairtable import Api as AirtableApi
import requests

print("=" * 55)
print("  🚀 MIGRACIÓN AIRTABLE → SUPABASE")
print("=" * 55)

print("\n📡 Paso 1: Conectando a Airtable...")
at_api = AirtableApi(AIRTABLE_API_KEY)

# Obtener la lista de tablas usando la API de metadatos
# La librería pyairtable necesita saber los nombres de las tablas
headers = {
    "Authorization": f"Bearer {AIRTABLE_API_KEY}",
    "Content-Type": "application/json"
}

response = requests.get(
    f"https://api.airtable.com/v0/meta/bases/{AIRTABLE_BASE_ID}/tables",
    headers=headers
)

if response.status_code != 200:
    print(f"❌ Error al obtener tablas: {response.status_code}")
    print(f"   Respuesta: {response.text}")
    print("   Verifica tu API key y Base ID")
    exit(1)

tables_meta = response.json()["tables"]
print(f"   ✅ Encontradas {len(tables_meta)} tablas:\n")

for i, table in enumerate(tables_meta, 1):
    field_count = len(table.get("fields", []))
    print(f"   {i:2d}. {table['name']} ({field_count} campos)")


# ─── PASO 2: Conectar a Supabase ─────────────────────────────
from supabase import create_client

print(f"\n📡 Paso 2: Conectando a Supabase...")
supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
print("   ✅ Conectado a Supabase\n")


# ─── PASO 3: Funciones auxiliares ─────────────────────────────
# Estas funciones convierten tipos de Airtable a PostgreSQL

def sanitize_name(name: str) -> str:
    """
    Convierte un nombre de tabla/campo de Airtable a un nombre
    válido para PostgreSQL.
    
    Ejemplo: "Mi Tabla Cool! (v2)" → "mi_tabla_cool_v2"
    
    ¿Por qué? PostgreSQL no acepta espacios ni caracteres
    especiales en nombres de columnas/tablas.
    """
    # Quitar acentos y caracteres especiales
    name = name.lower().strip()
    name = re.sub(r'[^a-z0-9_\s]', '', name)  # Solo letras, números, _ y espacios
    name = re.sub(r'\s+', '_', name)            # Espacios → guiones bajos
    name = re.sub(r'_+', '_', name)             # Múltiples _ → uno solo
    name = name.strip('_')                       # Quitar _ al inicio/final
    
    # Si empieza con número, agregar prefijo
    if name and name[0].isdigit():
        name = f"col_{name}"
    
    return name or "unnamed"


def airtable_type_to_postgres(field: dict) -> str:
    """
    Mapea un tipo de campo de Airtable al tipo equivalente en PostgreSQL.
    
    ¿Por qué un mapeo? Airtable y PostgreSQL usan nombres diferentes
    para conceptos similares. Por ejemplo:
      - Airtable "singleLineText" → PostgreSQL "TEXT"
      - Airtable "number" → PostgreSQL "NUMERIC"
    """
    at_type = field.get("type", "")
    
    # Mapeo de tipos (Airtable → PostgreSQL)
    type_map = {
        # Textos
        "singleLineText":    "TEXT",
        "multilineText":     "TEXT",
        "richText":          "TEXT",
        "email":             "TEXT",
        "url":               "TEXT",
        "phoneNumber":       "TEXT",
        
        # Números
        "number":            "NUMERIC",
        "percent":           "NUMERIC",
        "currency":          "NUMERIC",
        "rating":            "INTEGER",
        "autoNumber":        "SERIAL",
        "count":             "INTEGER",
        
        # Fechas
        "date":              "DATE",
        "dateTime":          "TIMESTAMPTZ",
        "createdTime":       "TIMESTAMPTZ",
        "lastModifiedTime":  "TIMESTAMPTZ",
        
        # Booleanos
        "checkbox":          "BOOLEAN",
        
        # Selección
        "singleSelect":      "TEXT",
        "multipleSelects":   "TEXT[]",     # Array de texto en PostgreSQL
        
        # Archivos y relaciones (se guardan como JSON)
        "multipleAttachments": "JSONB",
        "multipleRecordLinks": "JSONB",
        "multipleLookupValues": "JSONB",
        "formula":           "TEXT",
        "rollup":            "TEXT",
        "lookup":            "JSONB",
        
        # Otros
        "barcode":           "JSONB",
        "button":            "JSONB",
        "createdBy":         "JSONB",
        "lastModifiedBy":    "JSONB",
        "externalSyncSource":"TEXT",
        "aiText":            "TEXT",
    }
    
    return type_map.get(at_type, "TEXT")  # TEXT como fallback seguro


def convert_value(value, pg_type: str):
    """
    Convierte un valor de Airtable al formato correcto para PostgreSQL.
    
    Ejemplo: multipleSelects en Airtable es una lista Python ["a", "b"],
    pero PostgreSQL TEXT[] espera el formato {"a", "b"}.
    """
    if value is None:
        return None
    
    if pg_type == "BOOLEAN":
        return bool(value)
    
    if pg_type in ("NUMERIC", "INTEGER"):
        try:
            return float(value) if pg_type == "NUMERIC" else int(value)
        except (ValueError, TypeError):
            return None
    
    if pg_type == "JSONB":
        # Si ya es dict o list, lo dejamos tal cual
        # Supabase lo convierte automáticamente
        if isinstance(value, (dict, list)):
            return json.dumps(value)
        return json.dumps(value)
    
    if pg_type == "TEXT[]":
        # Arrays de texto
        if isinstance(value, list):
            return value
        return [str(value)]
    
    # Para TEXT, DATE, TIMESTAMPTZ → convertir a string
    return str(value) if value is not None else None


# ─── PASO 4: Crear tablas y migrar datos ─────────────────────
print("─" * 55)
print("📦 Paso 3: Migrando tablas...\n")

# Guardamos un resumen de la migración
migration_summary = []

for table_meta in tables_meta:
    table_name_original = table_meta["name"]
    table_name_pg = sanitize_name(table_name_original)
    fields = table_meta.get("fields", [])
    
    print(f"  📋 Tabla: {table_name_original} → {table_name_pg}")
    
    # ── 4a. Construir el SQL para crear la tabla ──
    # Mapeamos cada campo de Airtable a una columna PostgreSQL
    columns = []
    field_mapping = {}  # nombre_airtable → nombre_postgres
    
    for field in fields:
        col_name = sanitize_name(field["name"])
        pg_type = airtable_type_to_postgres(field)
        
        # Evitar duplicados (Airtable puede tener "Name" y "name")
        base_col = col_name
        counter = 1
        while col_name in field_mapping.values():
            col_name = f"{base_col}_{counter}"
            counter += 1
        
        field_mapping[field["name"]] = col_name
        
        # SERIAL se maneja diferente (es autoincremental)
        if pg_type == "SERIAL":
            columns.append(f'"{col_name}" SERIAL')
        else:
            columns.append(f'"{col_name}" {pg_type}')
    
    # Agregar columna para el ID original de Airtable (por si lo necesitas)
    columns.insert(0, '"airtable_id" TEXT UNIQUE')
    
    # Construir el CREATE TABLE
    columns_sql = ",\n    ".join(columns)
    create_sql = f"""
    CREATE TABLE IF NOT EXISTS "{table_name_pg}" (
        "id" BIGSERIAL PRIMARY KEY,
        {columns_sql}
    );
    """
    
    print(f"     🔧 Creando tabla con {len(fields)} columnas...")
    
    # Ejecutar el SQL en Supabase usando la API REST de PostgreSQL
    try:
        result = supabase.postgrest.rpc("", {}).execute()
    except:
        pass
    
    # Usamos la función SQL directa via postgrest
    # NOTA: Necesitamos ejecutar SQL raw, usamos el endpoint /rest/v1/rpc
    sql_response = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/exec_sql",
        headers={
            "apikey": SUPABASE_SERVICE_KEY,
            "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
            "Content-Type": "application/json"
        },
        json={"query": create_sql}
    )
    
    # Si la función exec_sql no existe, la creamos primero
    if sql_response.status_code == 404 or "could not find" in sql_response.text.lower():
        print("     ⚙️  Creando función auxiliar exec_sql en Supabase...")
        
        # Crear la función exec_sql usando el SQL Editor de Supabase
        create_func_sql = """
        CREATE OR REPLACE FUNCTION exec_sql(query TEXT)
        RETURNS void
        LANGUAGE plpgsql
        SECURITY DEFINER
        AS $$
        BEGIN
            EXECUTE query;
        END;
        $$;
        """
        
        # Intentar via la Management API
        mgmt_response = requests.post(
            f"{SUPABASE_URL}/rest/v1/rpc/exec_sql",
            headers={
                "apikey": SUPABASE_SERVICE_KEY,
                "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
                "Content-Type": "application/json"
            },
            json={"query": create_func_sql}
        )
        
        print("     ⚠️  ACCIÓN MANUAL NECESARIA:")
        print("        Ve al SQL Editor de Supabase y ejecuta esto:\n")
        print("        CREATE OR REPLACE FUNCTION exec_sql(query TEXT)")
        print("        RETURNS void LANGUAGE plpgsql SECURITY DEFINER")
        print("        AS $$ BEGIN EXECUTE query; END; $$;\n")
        print("        Luego vuelve a ejecutar este script.")
        print(f"\n        También puedes crear la tabla manualmente:")
        print(f"        {create_sql}")
        
        # Guardar el SQL completo en un archivo por si lo necesita
        with open(f"sql_{table_name_pg}.sql", "w") as f:
            f.write(f"-- Tabla: {table_name_original}\n")
            f.write(create_sql)
        
        print(f"        💾 SQL guardado en: sql_{table_name_pg}.sql")
        
        # Preguntar si continuar
        continuar = input("\n     ¿Continuar con las demás tablas? (s/n): ")
        if continuar.lower() != 's':
            exit(0)
        continue
    
    if sql_response.status_code not in (200, 204):
        print(f"     ⚠️  Error creando tabla: {sql_response.text[:200]}")
        # Guardar SQL para revisión manual
        with open(f"sql_{table_name_pg}.sql", "w") as f:
            f.write(create_sql)
        print(f"     💾 SQL guardado en: sql_{table_name_pg}.sql")
        continue
    
    print(f"     ✅ Tabla creada")
    
    # ── 4b. Leer registros de Airtable ──
    print(f"     📥 Leyendo registros de Airtable...")
    
    at_table = at_api.table(AIRTABLE_BASE_ID, table_name_original)
    
    try:
        all_records = at_table.all()
    except Exception as e:
        print(f"     ❌ Error leyendo registros: {e}")
        migration_summary.append({
            "tabla": table_name_original,
            "status": "❌ Error leyendo",
            "registros": 0
        })
        continue
    
    print(f"     📊 {len(all_records)} registros encontrados")
    
    if not all_records:
        migration_summary.append({
            "tabla": table_name_original,
            "status": "✅ Vacía",
            "registros": 0
        })
        continue
    
    # ── 4c. Insertar datos en Supabase ──
    print(f"     📤 Insertando en Supabase...")
    
    # Preparar los datos en lotes de 500 (Supabase tiene límite)
    BATCH_SIZE = 500
    rows_to_insert = []
    
    for record in all_records:
        row = {"airtable_id": record["id"]}
        
        for at_field_name, pg_col_name in field_mapping.items():
            value = record["fields"].get(at_field_name)
            pg_type = "TEXT"  # tipo por defecto
            
            # Buscar el tipo correcto
            for f in fields:
                if f["name"] == at_field_name:
                    pg_type = airtable_type_to_postgres(f)
                    break
            
            row[pg_col_name] = convert_value(value, pg_type)
        
        rows_to_insert.append(row)
    
    # Insertar en lotes
    inserted = 0
    errors = 0
    
    for i in range(0, len(rows_to_insert), BATCH_SIZE):
        batch = rows_to_insert[i:i + BATCH_SIZE]
        
        try:
            result = supabase.table(table_name_pg).upsert(
                batch,
                on_conflict="airtable_id"  # Si ya existe, actualizar
            ).execute()
            inserted += len(batch)
            
            # Mostrar progreso
            progress = min(inserted, len(rows_to_insert))
            print(f"        {progress}/{len(rows_to_insert)} registros...", end="\r")
            
        except Exception as e:
            errors += len(batch)
            print(f"\n     ⚠️  Error en lote {i//BATCH_SIZE + 1}: {str(e)[:100]}")
            
            # Intentar uno por uno para identificar el problemático
            for row in batch:
                try:
                    supabase.table(table_name_pg).upsert(
                        row,
                        on_conflict="airtable_id"
                    ).execute()
                    inserted += 1
                    errors -= 1
                except Exception as e2:
                    print(f"        ❌ Registro {row.get('airtable_id', '?')}: {str(e2)[:80]}")
        
        # Pequeña pausa para no saturar la API
        time.sleep(0.1)
    
    print(f"     ✅ {inserted} insertados, {errors} errores")
    
    migration_summary.append({
        "tabla": table_name_original,
        "tabla_pg": table_name_pg,
        "status": "✅ Migrada" if errors == 0 else f"⚠️ {errors} errores",
        "registros": inserted
    })
    
    print()


# ─── PASO 5: Resumen final ───────────────────────────────────
print("\n" + "=" * 55)
print("  📊 RESUMEN DE LA MIGRACIÓN")
print("=" * 55)

total_records = 0
for item in migration_summary:
    status = item["status"]
    nombre = item["tabla"]
    regs = item["registros"]
    total_records += regs
    print(f"  {status:20s} | {nombre:30s} | {regs:5d} registros")

print(f"\n  Total: {total_records} registros migrados en {len(migration_summary)} tablas")
print("=" * 55)

# Guardar resumen en archivo JSON
with open("migration_report.json", "w") as f:
    json.dump({
        "fecha": datetime.now().isoformat(),
        "base_id": AIRTABLE_BASE_ID,
        "tablas": migration_summary
    }, f, indent=2, ensure_ascii=False)

print("\n📄 Reporte guardado en: migration_report.json")
print("\n🎉 ¡Migración completada!")
print("\n💡 Próximos pasos:")
print("   1. Ve a Supabase → Table Editor para verificar tus datos")
print("   2. Configura las Row Level Security (RLS) policies")
print("   3. Crea los índices que necesites para consultas rápidas")
print("   4. Actualiza tu aplicación para usar Supabase en lugar de Airtable")