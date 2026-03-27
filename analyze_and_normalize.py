"""
=============================================================
  ANÁLISIS Y NORMALIZACIÓN DE DATOS EN SUPABASE
=============================================================
  Este script:
  1. Se conecta a tu Supabase
  2. Analiza los 69 campos de "base_general" (y cualquier otra tabla)
  3. Clasifica cada campo por tipo REAL (no el que dice PostgreSQL)
  4. Te muestra un reporte de qué hay que corregir
  5. Ejecuta las correcciones con tu aprobación

  ¿Por qué es necesario?
  Airtable guarda TODO como texto internamente. Al migrar,
  campos como teléfonos, códigos postales y IDs terminan
  como NUMERIC cuando deberían ser TEXT.

  Requisitos (ya los tienes):
    pip3 install supabase python-dotenv requests
=============================================================
"""

import os
import re
import json
import requests
from collections import Counter
from dotenv import load_dotenv
from supabase import create_client

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_KEY")

supabase = create_client(SUPABASE_URL, SUPABASE_KEY)

headers = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Content-Type": "application/json"
}


def exec_sql(sql):
    """Ejecuta SQL en Supabase."""
    resp = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/exec_sql",
        headers=headers,
        json={"query": sql}
    )
    return resp.status_code in (200, 204)


# ─── PASO 1: Elegir tabla ────────────────────────────────
print("=" * 60)
print("  🔍 ANÁLISIS Y NORMALIZACIÓN DE DATOS")
print("=" * 60)

# Puedes cambiar esto a cualquier tabla
TABLE = input("\n  Nombre de la tabla a analizar (default: base_general): ").strip()
if not TABLE:
    TABLE = "base_general"

print(f"\n  📋 Analizando tabla: {TABLE}")
print(f"  📥 Descargando registros...\n")


# ─── PASO 2: Descargar todos los registros ────────────────
# Supabase limita a 1000 por petición, hacemos paginación
all_rows = []
offset = 0
BATCH = 1000

while True:
    result = supabase.table(TABLE).select("*").range(offset, offset + BATCH - 1).execute()
    rows = result.data
    if not rows:
        break
    all_rows.extend(rows)
    offset += BATCH
    if len(rows) < BATCH:
        break

print(f"  📊 {len(all_rows)} registros descargados")
print(f"  📊 {len(all_rows[0].keys()) if all_rows else 0} columnas\n")

if not all_rows:
    print("  ⚠️  Tabla vacía, nada que analizar")
    exit(0)

columns = list(all_rows[0].keys())


# ─── PASO 3: Analizar cada columna ───────────────────────
"""
Para cada columna vamos a detectar su tipo REAL:

  - PHONE:    Parece teléfono (10+ dígitos, puede tener +, -, espacios)
  - ID/CODE:  Números que son identificadores (código postal, folio, etc.)
  - NUMERIC:  Números reales para operaciones matemáticas (montos, cantidades)
  - DATE:     Fechas
  - EMAIL:    Correos electrónicos
  - URL:      URLs
  - BOOLEAN:  Verdadero/Falso
  - CATEGORY: Texto con pocas opciones repetidas (como un select)
  - TEXT:     Texto libre
  - JSON:     Datos estructurados
  - EMPTY:    Columna vacía o casi vacía
"""

# Patrones de detección
PHONE_PATTERNS = [
    r'^\+?\d{10,15}$',                    # +5212345678901
    r'^\d{2,4}[-.\s]\d{3,4}[-.\s]\d{4}$', # 55-1234-5678
    r'^\(\d{2,4}\)\s?\d{3,4}[-.\s]?\d{4}$', # (55) 1234-5678
    r'^\d{10}$',                           # 5512345678
]

EMAIL_PATTERN = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
URL_PATTERN = r'^https?://'
DATE_PATTERN = r'^\d{4}-\d{2}-\d{2}'

# Palabras clave en nombres de columna que indican tipo
PHONE_KEYWORDS = ['telefono', 'phone', 'celular', 'movil', 'tel', 'whatsapp', 'contacto_tel', 'numero_tel']
ID_KEYWORDS = ['codigo', 'folio', 'postal', 'cp', 'zip', 'clave', 'numero_de', 'num_', 'no_', 'id_', '_id', 'rfc']
DATE_KEYWORDS = ['fecha', 'date', 'created', 'modified', 'inicio', 'fin', 'vencimiento']
MONEY_KEYWORDS = ['precio', 'costo', 'monto', 'total', 'pago', 'cobro', 'saldo', 'tarifa', 'renta', 'importe']

def detect_column_type(col_name, values):
    """
    Detecta el tipo REAL de una columna analizando sus valores
    y el nombre de la columna.
    
    Retorna: (tipo, confianza, detalle)
    """
    col_lower = col_name.lower()
    
    # Filtrar valores no nulos
    non_null = [v for v in values if v is not None and str(v).strip() != '']
    
    if len(non_null) == 0:
        return ("EMPTY", 100, "Sin datos")
    
    # Si es JSON/dict/list
    json_count = sum(1 for v in non_null if isinstance(v, (dict, list)))
    if json_count > len(non_null) * 0.5:
        return ("JSON", 90, f"{json_count} valores JSON")
    
    # Convertir todo a string para análisis
    str_values = [str(v).strip() for v in non_null]
    
    # Detectar booleanos
    bool_vals = {'true', 'false', 'True', 'False', '1', '0', 'si', 'no', 'Si', 'No', 'SI', 'NO'}
    bool_count = sum(1 for v in str_values if v in bool_vals or isinstance(values[0], bool))
    if bool_count > len(non_null) * 0.8:
        return ("BOOLEAN", 95, f"Valores: {Counter(str_values).most_common(3)}")
    
    # Detectar emails
    email_count = sum(1 for v in str_values if re.match(EMAIL_PATTERN, v))
    if email_count > len(non_null) * 0.5:
        return ("EMAIL", 95, f"{email_count} emails")
    
    # Detectar URLs
    url_count = sum(1 for v in str_values if re.match(URL_PATTERN, v))
    if url_count > len(non_null) * 0.5:
        return ("URL", 90, f"{url_count} URLs")
    
    # Detectar fechas
    date_count = sum(1 for v in str_values if re.match(DATE_PATTERN, v))
    if date_count > len(non_null) * 0.5 or any(kw in col_lower for kw in DATE_KEYWORDS):
        if date_count > len(non_null) * 0.3:
            return ("DATE", 85, f"{date_count} fechas detectadas")
    
    # Detectar teléfonos
    # Primero por nombre de columna
    is_phone_name = any(kw in col_lower for kw in PHONE_KEYWORDS)
    phone_count = 0
    for v in str_values:
        clean = re.sub(r'[\s\-\.\(\)\+]', '', v)
        if clean.isdigit() and 7 <= len(clean) <= 15:
            phone_count += 1
        elif any(re.match(p, v) for p in PHONE_PATTERNS):
            phone_count += 1
    
    if is_phone_name and phone_count > len(non_null) * 0.3:
        return ("PHONE", 95, f"Nombre indica teléfono + {phone_count} coincidencias")
    if phone_count > len(non_null) * 0.7:
        return ("PHONE", 80, f"{phone_count} parecen teléfonos")
    
    # Detectar IDs/Códigos numéricos
    is_id_name = any(kw in col_lower for kw in ID_KEYWORDS)
    numeric_str_count = sum(1 for v in str_values if re.match(r'^-?\d+\.?\d*$', v))
    
    if is_id_name and numeric_str_count > len(non_null) * 0.3:
        return ("ID/CODE", 90, f"Nombre indica código + {numeric_str_count} numéricos")
    
    # Detectar números reales (para operaciones matemáticas)
    is_money_name = any(kw in col_lower for kw in MONEY_KEYWORDS)
    
    if numeric_str_count > len(non_null) * 0.7:
        # Son números, pero ¿son para sumar o son IDs?
        try:
            num_vals = [float(v) for v in str_values if re.match(r'^-?\d+\.?\d*$', v)]
            if num_vals:
                avg = sum(num_vals) / len(num_vals)
                max_val = max(num_vals)
                unique_ratio = len(set(num_vals)) / len(num_vals)
                
                # Si los números son muy grandes (>999999) y la mayoría son únicos = probablemente IDs/teléfonos
                if max_val > 999999 and unique_ratio > 0.8 and not is_money_name:
                    return ("ID/CODE", 75, f"Números grandes y únicos (max: {max_val:.0f})")
                
                # Si hay decimales o el nombre sugiere dinero = numérico
                has_decimals = any('.' in v for v in str_values if re.match(r'^-?\d+\.?\d*$', v))
                if is_money_name or has_decimals:
                    return ("NUMERIC", 90, f"Promedio: {avg:.2f}, Max: {max_val:.2f}")
                
                # Pocos valores únicos + rango pequeño = probablemente rating/cantidad
                if max_val <= 10000 and unique_ratio < 0.5:
                    return ("NUMERIC", 80, f"Rango: 0-{max_val:.0f}, Promedio: {avg:.1f}")
                
                return ("NUMERIC", 70, f"Promedio: {avg:.2f}, Max: {max_val:.0f}")
        except:
            pass
    
    # Detectar categorías (pocas opciones únicas)
    unique = set(str_values)
    unique_ratio = len(unique) / len(non_null) if non_null else 1
    
    if 1 < len(unique) <= 30 and unique_ratio < 0.15:
        top3 = Counter(str_values).most_common(3)
        return ("CATEGORY", 85, f"{len(unique)} opciones: {', '.join(t[0][:20] for t in top3)}")
    
    # Default: texto
    avg_len = sum(len(v) for v in str_values) / len(str_values)
    return ("TEXT", 60, f"Largo promedio: {avg_len:.0f} chars")


# ─── PASO 4: Ejecutar análisis ───────────────────────────
print("─" * 60)
print("  📊 RESULTADO DEL ANÁLISIS")
print("─" * 60)

analysis = {}
needs_fix = []

# Separar por tipo para mejor visualización
type_groups = {}

for col in columns:
    values = [row.get(col) for row in all_rows]
    detected_type, confidence, detail = detect_column_type(col, values)
    non_null_count = sum(1 for v in values if v is not None and str(v).strip() != '')
    
    analysis[col] = {
        "type": detected_type,
        "confidence": confidence,
        "detail": detail,
        "non_null": non_null_count,
        "total": len(values),
        "fill_pct": round(non_null_count / len(values) * 100, 1)
    }
    
    if detected_type not in type_groups:
        type_groups[detected_type] = []
    type_groups[detected_type].append(col)

# Mostrar agrupado por tipo
TYPE_ICONS = {
    "PHONE": "📱", "ID/CODE": "🔢", "NUMERIC": "💰", "DATE": "📅",
    "EMAIL": "📧", "URL": "🔗", "BOOLEAN": "✅", "CATEGORY": "📊",
    "TEXT": "📝", "JSON": "📦", "EMPTY": "⬜"
}

for type_name in ["PHONE", "ID/CODE", "NUMERIC", "DATE", "EMAIL", "URL", "BOOLEAN", "CATEGORY", "TEXT", "JSON", "EMPTY"]:
    if type_name not in type_groups:
        continue
    
    cols = type_groups[type_name]
    icon = TYPE_ICONS.get(type_name, "❓")
    
    print(f"\n  {icon} {type_name} ({len(cols)} campos)")
    print(f"  {'─' * 56}")
    
    for col in cols:
        info = analysis[col]
        fill = f"{info['fill_pct']}%"
        print(f"    {col[:35]:35s} | {fill:>5s} lleno | {info['detail'][:40]}")


# ─── PASO 5: Identificar campos problemáticos ────────────
print(f"\n\n{'=' * 60}")
print("  🔧 CAMPOS QUE NECESITAN CORRECCIÓN")
print("=" * 60)

fixes = []

for col in columns:
    info = analysis[col]
    
    # Teléfonos almacenados como NUMERIC → deben ser TEXT
    if info["type"] == "PHONE":
        fixes.append({
            "col": col,
            "issue": "Teléfono guardado como número",
            "fix": "Convertir a TEXT",
            "sql": f'ALTER TABLE "{TABLE}" ALTER COLUMN "{col}" TYPE TEXT USING "{col}"::TEXT;',
            "priority": "ALTA"
        })
    
    # IDs/Códigos como NUMERIC → deben ser TEXT
    elif info["type"] == "ID/CODE":
        fixes.append({
            "col": col,
            "issue": "Código/ID guardado como número",
            "fix": "Convertir a TEXT",
            "sql": f'ALTER TABLE "{TABLE}" ALTER COLUMN "{col}" TYPE TEXT USING "{col}"::TEXT;',
            "priority": "ALTA"
        })

# Mostrar correcciones
if not fixes:
    print("\n  ✅ ¡No se encontraron campos problemáticos!")
else:
    for i, fix in enumerate(fixes, 1):
        print(f"\n  {i}. [{fix['priority']}] {fix['col']}")
        print(f"     Problema: {fix['issue']}")
        print(f"     Solución: {fix['fix']}")


# ─── PASO 6: Aplicar correcciones ────────────────────────
if fixes:
    print(f"\n{'─' * 60}")
    respuesta = input(f"\n  ¿Aplicar {len(fixes)} correcciones? (s/n): ").strip().lower()
    
    if respuesta == 's':
        print(f"\n  🔧 Aplicando correcciones...\n")
        
        for fix in fixes:
            print(f"    → {fix['col']}...", end=" ")
            if exec_sql(fix['sql']):
                print("✅")
            else:
                print("❌ (puede que ya esté como TEXT)")
        
        # Recargar schema de PostgREST
        exec_sql("NOTIFY pgrst, 'reload schema';")
        print(f"\n  ✅ ¡Correcciones aplicadas!")
    else:
        print("\n  ⏭️  Correcciones omitidas")

        # Guardar SQL para ejecución manual
        with open(f"fix_{TABLE}_types.sql", "w") as f:
            f.write(f"-- Correcciones para {TABLE}\n\n")
            for fix in fixes:
                f.write(f"-- {fix['issue']}: {fix['col']}\n")
                f.write(f"{fix['sql']}\n\n")
        print(f"  💾 SQL guardado en: fix_{TABLE}_types.sql")


# ─── PASO 7: Guardar reporte completo ────────────────────
report = {
    "tabla": TABLE,
    "total_registros": len(all_rows),
    "total_columnas": len(columns),
    "analisis": analysis,
    "correcciones": [{"col": f["col"], "issue": f["issue"], "fix": f["fix"]} for f in fixes],
    "resumen_tipos": {t: len(cols) for t, cols in type_groups.items()}
}

with open(f"analysis_{TABLE}.json", "w") as f:
    json.dump(report, f, indent=2, ensure_ascii=False)

print(f"\n  📄 Reporte completo guardado en: analysis_{TABLE}.json")


# ─── PASO 8: Recomendaciones para el dashboard ───────────
print(f"\n\n{'=' * 60}")
print("  💡 RECOMENDACIONES PARA TU DASHBOARD")
print("=" * 60)

print(f"""
  Campos buenos para GRÁFICAS de pastel/barras:
  (categorías con pocas opciones)""")
for col in type_groups.get("CATEGORY", []):
    info = analysis[col]
    print(f"    ✓ {col} → {info['detail'][:50]}")

print(f"""
  Campos buenos para MÉTRICAS numéricas:
  (sumas, promedios, máximos)""")
for col in type_groups.get("NUMERIC", []):
    info = analysis[col]
    print(f"    ✓ {col} → {info['detail'][:50]}")

print(f"""
  Campos buenos para FILTROS:""")
for col in type_groups.get("CATEGORY", [])[:5]:
    print(f"    ✓ {col}")
for col in type_groups.get("DATE", [])[:3]:
    print(f"    ✓ {col}")

print(f"""
  Campos a EXCLUIR de análisis numérico:
  (parecen números pero no lo son)""")
for col in type_groups.get("PHONE", []):
    print(f"    ✗ {col} (teléfono)")
for col in type_groups.get("ID/CODE", []):
    print(f"    ✗ {col} (código/ID)")

print(f"\n{'=' * 60}")
print("  ✨ Análisis completo. Usa estos resultados para configurar")
print("     tu dashboard y mostrar solo lo que tiene sentido.")
print("=" * 60)