
    CREATE TABLE IF NOT EXISTS "registro_de_llamadas" (
        "id" BIGSERIAL PRIMARY KEY,
        "airtable_id" TEXT UNIQUE,
    "id" TEXT,
    "number" TEXT,
    "telefono_cliente" TEXT,
    "recording" TEXT,
    "duration" TEXT,
    "name" TEXT,
    "direction" TEXT,
    "cliente_relacionado" JSONB,
    "nombre_del_cliente_from_cliente_relacionado" JSONB,
    "whatsapp_del_contacto_from_cliente_relacionado" JSONB,
    "fecha_raw" NUMERIC,
    "fecha" TEXT
    );
    