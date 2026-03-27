"""
=============================================================
  CORRECCIÓN DE TABLAS CON ERRORES
=============================================================
  Arregla las 5 tablas que fallaron en la migración inicial.
  
  Problemas encontrados:
  
  1. "solicitud_de_soporte_general" → Ya existía (la corriste antes)
  2. "evaluacin_de_aroma_innova"   → Ya existía
  3. "diagnostico_de_equipos"      → Ya existía
  4. "registro_de_llamadas"        → Tiene un campo llamado "id" que
                                     choca con nuestra columna "id"
  5. "clientes_unicos_reporte..."  → Mismo problema del campo "id"
  
  6. "registro_de_incidencias_ultra_acoustics" → Nombre de columna
     demasiado largo (PostgreSQL permite max 63 caracteres)
  7. "evaluar_demo_ultra_acoustics" → Mismo problema
  8. "encuesta_de_satisfaccin"     → Problema con el caché de schema
  
  Solución: Borrar las tablas problemáticas y recrearlas con
  nombres de columna corregidos.
=============================================================
"""

import os
import re
import json
import time
import requests
from dotenv import load_dotenv
from pyairtable import Api as AirtableApi
from supabase import create_client

load_dotenv()

AIRTABLE_API_KEY = os.getenv("AIRTABLE_API_KEY")
AIRTABLE_BASE_ID = os.getenv("AIRTABLE_BASE_ID")
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY")

# Conexiones
at_api = AirtableApi(AIRTABLE_API_KEY)
supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

headers_sb = {
    "apikey": SUPABASE_SERVICE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
    "Content-Type": "application/json"
}

headers_at = {
    "Authorization": f"Bearer {AIRTABLE_API_KEY}",
    "Content-Type": "application/json"
}

print("=" * 55)
print("  🔧 CORRECCIÓN DE TABLAS CON ERRORES")
print("=" * 55)


def exec_sql(sql: str) -> bool:
    """Ejecuta SQL en Supabase y retorna True si fue exitoso."""
    resp = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/exec_sql",
        headers=headers_sb,
        json={"query": sql}
    )
    if resp.status_code in (200, 204):
        return True
    else:
        print(f"     ❌ Error SQL: {resp.text[:200]}")
        return False


def sanitize_name(name: str, max_length: int = 55) -> str:
    """
    Igual que antes, pero ahora TRUNCAMOS a 55 caracteres.
    
    ¿Por qué 55 y no 63?
    PostgreSQL permite 63 caracteres max para nombres de columna.
    Dejamos margen por si hay que agregar sufijos (_1, _2, etc.)
    """
    name = name.lower().strip()
    name = re.sub(r'[^a-z0-9_\s]', '', name)
    name = re.sub(r'\s+', '_', name)
    name = re.sub(r'_+', '_', name)
    name = name.strip('_')
    
    if name and name[0].isdigit():
        name = f"col_{name}"
    
    # TRUNCAR para evitar el error de nombre largo
    if len(name) > max_length:
        name = name[:max_length].rstrip('_')
    
    return name or "unnamed"


def airtable_type_to_postgres(field: dict) -> str:
    """Mapeo de tipos Airtable → PostgreSQL."""
    at_type = field.get("type", "")
    type_map = {
        "singleLineText": "TEXT", "multilineText": "TEXT",
        "richText": "TEXT", "email": "TEXT", "url": "TEXT",
        "phoneNumber": "TEXT", "number": "NUMERIC",
        "percent": "NUMERIC", "currency": "NUMERIC",
        "rating": "INTEGER", "autoNumber": "INTEGER",
        "count": "INTEGER", "date": "DATE",
        "dateTime": "TIMESTAMPTZ", "createdTime": "TIMESTAMPTZ",
        "lastModifiedTime": "TIMESTAMPTZ", "checkbox": "BOOLEAN",
        "singleSelect": "TEXT", "multipleSelects": "TEXT[]",
        "multipleAttachments": "JSONB", "multipleRecordLinks": "JSONB",
        "multipleLookupValues": "JSONB", "formula": "TEXT",
        "rollup": "TEXT", "lookup": "JSONB", "barcode": "JSONB",
        "button": "JSONB", "createdBy": "JSONB",
        "lastModifiedBy": "JSONB", "externalSyncSource": "TEXT",
        "aiText": "TEXT",
    }
    return type_map.get(at_type, "TEXT")


def convert_value(value, pg_type: str):
    """Convierte valores de Airtable a PostgreSQL."""
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
        if isinstance(value, (dict, list)):
            return json.dumps(value)
        return json.dumps(value)
    if pg_type == "TEXT[]":
        if isinstance(value, list):
            return value
        return [str(value)]
    return str(value) if value is not None else None


def migrate_table(table_name_original: str, table_name_pg: str, fields: list):
    """Borra la tabla si existe, la recrea y migra los datos."""
    
    print(f"\n  📋 {table_name_original} → {table_name_pg}")
    
    # Paso 1: Borrar tabla existente (CASCADE por si hay dependencias)
    print(f"     🗑️  Borrando tabla vieja si existe...")
    exec_sql(f'DROP TABLE IF EXISTS "{table_name_pg}" CASCADE;')
    
    # Paso 2: Construir columnas con nombres corregidos
    columns = ['"airtable_id" TEXT UNIQUE']
    field_mapping = {}
    used_names = set()
    
    for field in fields:
        col_name = sanitize_name(field["name"])
        pg_type = airtable_type_to_postgres(field)
        
        # Evitar que un campo se llame "id" (choca con nuestra PK)
        if col_name == "id":
            col_name = "at_id"
        
        # Evitar duplicados
        base_col = col_name
        counter = 1
        while col_name in used_names:
            col_name = f"{base_col}_{counter}"
            counter += 1
        
        used_names.add(col_name)
        field_mapping[field["name"]] = col_name
        
        if pg_type == "SERIAL":
            columns.append(f'"{col_name}" INTEGER')
        else:
            columns.append(f'"{col_name}" {pg_type}')
    
    columns_sql = ",\n    ".join(columns)
    create_sql = f'''
    CREATE TABLE IF NOT EXISTS "{table_name_pg}" (
        "id" BIGSERIAL PRIMARY KEY,
        {columns_sql}
    );
    '''
    
    print(f"     🔧 Creando tabla con {len(fields)} columnas...")
    if not exec_sql(create_sql):
        print(f"     💾 SQL guardado en: fix_sql_{table_name_pg}.sql")
        with open(f"fix_sql_{table_name_pg}.sql", "w") as f:
            f.write(create_sql)
        return
    
    # Recargar el schema cache de PostgREST
    # Supabase necesita unos segundos para registrar la nueva tabla
    print(f"     ⏳ Esperando a que Supabase registre la tabla...")
    time.sleep(3)
    
    # Notificar a PostgREST que recargue el schema
    exec_sql("NOTIFY pgrst, 'reload schema';")
    time.sleep(2)
    
    print(f"     ✅ Tabla creada")
    
    # Paso 3: Leer registros de Airtable
    print(f"     📥 Leyendo registros de Airtable...")
    at_table = at_api.table(AIRTABLE_BASE_ID, table_name_original)
    
    try:
        all_records = at_table.all()
    except Exception as e:
        print(f"     ❌ Error leyendo: {e}")
        return
    
    print(f"     📊 {len(all_records)} registros encontrados")
    
    if not all_records:
        print(f"     ✅ Tabla vacía, nada que insertar")
        return
    
    # Paso 4: Insertar datos
    print(f"     📤 Insertando...")
    
    BATCH_SIZE = 200  # Lotes más pequeños para evitar problemas
    inserted = 0
    errors = 0
    
    for i in range(0, len(all_records), BATCH_SIZE):
        batch_records = all_records[i:i + BATCH_SIZE]
        rows = []
        
        for record in batch_records:
            row = {"airtable_id": record["id"]}
            for at_name, pg_name in field_mapping.items():
                value = record["fields"].get(at_name)
                pg_type = "TEXT"
                for f in fields:
                    if f["name"] == at_name:
                        pg_type = airtable_type_to_postgres(f)
                        break
                row[pg_name] = convert_value(value, pg_type)
            rows.append(row)
        
        try:
            supabase.table(table_name_pg).upsert(
                rows, on_conflict="airtable_id"
            ).execute()
            inserted += len(rows)
            print(f"        {inserted}/{len(all_records)}...", end="\r")
        except Exception as e:
            # Intentar uno por uno
            for row in rows:
                try:
                    supabase.table(table_name_pg).upsert(
                        row, on_conflict="airtable_id"
                    ).execute()
                    inserted += 1
                except Exception as e2:
                    errors += 1
                    if errors <= 3:  # Solo mostrar los primeros 3
                        print(f"        ❌ {row.get('airtable_id', '?')}: {str(e2)[:80]}")
        
        time.sleep(0.1)
    
    print(f"     ✅ {inserted} insertados, {errors} errores")


# ─── Obtener metadatos de las tablas ──────────────────────────
response = requests.get(
    f"https://api.airtable.com/v0/meta/bases/{AIRTABLE_BASE_ID}/tables",
    headers=headers_at
)
tables_meta = response.json()["tables"]

# ─── Tablas que necesitan corrección ──────────────────────────
tablas_a_corregir = [
    "Solicitud de Soporte General",
    "Evaluación de aroma Innova",
    "Registro de incidencias Ultra Acoustics",
    "Evaluar Demo Ultra Acoustics",
    "Registro de llamadas",
    "Clientes unicos Reporte - 18_2_26, 10_06_Página sin título_Tabla",
    "Diagnostico de equipos",
    "Encuesta de satisfacción",
]

print(f"\n  Tablas a corregir: {len(tablas_a_corregir)}")

for table_meta in tables_meta:
    if table_meta["name"] in tablas_a_corregir:
        table_pg = sanitize_name(table_meta["name"])
        migrate_table(
            table_meta["name"],
            table_pg,
            table_meta.get("fields", [])
        )

print("\n" + "=" * 55)
print("  🎉 ¡Corrección completada!")
print("=" * 55)
print("\n  Revisa estas tablas en Supabase → Table Editor")
print("  para confirmar que los datos están correctos.")