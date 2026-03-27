
    CREATE TABLE IF NOT EXISTS "evaluacin_de_aroma_innova" (
        "id" BIGSERIAL PRIMARY KEY,
        "airtable_id" TEXT UNIQUE,
    "id" SERIAL,
    "nombre_de_sucursal_from_innova_propiedades" JSONB,
    "pregunta" TEXT,
    "innova_propiedades" JSONB,
    "la_cantidad_de_equipos_instalados_actualmente_cumple_con_tus_expectativas" TEXT,
    "hay_algo_que_podamos_hacer_para_mejorar_tu_experiencia_con_el_producto" TEXT,
    "solicitud_de_soporte_general" JSONB,
    "solicitud_de_levantamiento" TEXT,
    "sucursal_from_pregunta" JSONB,
    "nombre_de_sucursal_from_pregunta" JSONB,
    "zona_from_pregunta" JSONB,
    "copia_de_solicitud_de_soporte_general" TEXT,
    "copia_de_solicitud_de_soporte_general_1" TEXT
    );
    