
    CREATE TABLE IF NOT EXISTS "clientes_unicos_reporte_18_2_26_10_06_pagina_sin_titulo_tabla" (
        "id" BIGSERIAL PRIMARY KEY,
        "airtable_id" TEXT UNIQUE,
    "id" NUMERIC,
    "name" TEXT,
    "propiedades_unicas" NUMERIC,
    "social_reason" TEXT,
    "phone" TEXT,
    "email" TEXT
    );
    