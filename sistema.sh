#!/bin/bash
# ==============================================================================
# TP 13 - Gobernanza de Procesos y Tríada CIA
# Archivo: sistema.sh
# Objetivo: Automatizar tareas críticas de mantenimiento garantizando los pilares
#           de Integridad (backups de BD) y Disponibilidad (monitoreo de recursos).
# ==============================================================================

# Control de Robustez y Fallos Tempranos:
# -e: Detiene el script inmediatamente si algún comando retorna código de error != 0.
# -u: Trata el uso de variables no declaradas como un error fatal.
# -o pipefail: El retorno de un pipeline (|) será el del último comando que falle,
#              evitando que errores intermedios pasen desapercibidos.
set -euo pipefail

# ------------------------------------------------------------------------------
# Variables de configuración
# ------------------------------------------------------------------------------
FECHA=$(date +"%Y%m%d-%H%M%S")
CARPETA_BACKUP="/backups"
CARPETA_REPORTES="/backups/reportes"
COMPOSE_DIR="/home/alumno/Operaciones-1-guia-hecha/guia-06"

# ------------------------------------------------------------------------------
# Función: crear_backup
# Pilar CIA: INTEGRIDAD
# Descripción: Realiza un volcado lógico consistente de la base de datos PostgreSQL
#              utilizando pg_dump dentro del contenedor Docker. Genera una copia con 
#              timestamp para histórico y un archivo estático 'notes_db.sql' para 
#              que el script de auditoría (Paso 4) pueda validar la integridad.
# ------------------------------------------------------------------------------
crear_backup() {
    echo "Creando backup de la base de datos..."
    mkdir -p "$CARPETA_BACKUP"

    # Ejecutar pg_dump dentro del contenedor db gestionado por docker compose
    docker compose --project-directory "$COMPOSE_DIR" exec -T db \
        pg_dump -U postgres notesdb \
        > "$CARPETA_BACKUP/notes_db-$FECHA.sql"

    # Duplicar con nombre fijo requerido por verificar-permisos.sh
    cp "$CARPETA_BACKUP/notes_db-$FECHA.sql" \
       "$CARPETA_BACKUP/notes_db.sql"

    echo "Backup generado exitosamente en $CARPETA_BACKUP/notes_db.sql"
}

# ------------------------------------------------------------------------------
# Función: reporte_cpu
# Pilar CIA: DISPONIBILIDAD
# Descripción: Recolecta métricas de carga del procesador y tiempo de actividad
#              del sistema para monitorear posible saturación o degradación de servicio.
# ------------------------------------------------------------------------------
reporte_cpu() {
    echo "Generando reporte de CPU..."
    mkdir -p "$CARPETA_REPORTES"
    {
        echo "=== REPORTE DE ESTADO DE CPU Y CARGA ==="
        echo "Fecha y hora: $(date)"
        echo "--- UPTIME ---"
        uptime
        echo "--- ARQUITECTURA / CPU ---"
        lscpu
    } > "$CARPETA_REPORTES/cpu-$FECHA.txt"

    echo "Reporte de CPU guardado en $CARPETA_REPORTES/cpu-$FECHA.txt"
}

# ------------------------------------------------------------------------------
# Función: reporte_disco
# Pilar CIA: DISPONIBILIDAD
# Descripción: Audita el uso del sistema de archivos y espacio libre disponible,
#              permitiendo prevenir caídas del servicio por agotamiento de almacenamiento.
# ------------------------------------------------------------------------------
reporte_disco() {
    echo "Generando reporte de disco..."
    mkdir -p "$CARPETA_REPORTES"
    {
        echo "=== REPORTE DE USO DE DISCO ==="
        echo "Fecha y hora: $(date)"
        echo "--- ESPACIO EN PARTICIONES (df -h) ---"
        df -h
    } > "$CARPETA_REPORTES/disco-$FECHA.txt"

    echo "Reporte de disco guardado en $CARPETA_REPORTES/disco-$FECHA.txt"
}

# ------------------------------------------------------------------------------
# Flujo Principal de Ejecución
# ------------------------------------------------------------------------------
echo "Iniciando tareas de mantenimiento del sistema..."
crear_backup
reporte_cpu
reporte_disco

echo "Mantenimiento terminado correctamente."

