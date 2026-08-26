#!/bin/bash
# ==============================================================================
# TP 13 - Gobernanza de Procesos y Tríada CIA (UNAHUR)
# Archivo: orquestar-mantenimiento-auditoria.sh
# Objetivo: Orquestar secuencialmente el mantenimiento operativo (sistema.sh)
#           y la validación automatizada de seguridad (verificar-permisos.sh).
# ==============================================================================

set -euo pipefail

# Definición de rutas operativas
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_MANTENIMIENTO="$SCRIPT_DIR/sistema.sh"
SCRIPT_AUDITORIA="$SCRIPT_DIR/verificar-permisos.sh"

echo "============================================================"
echo "    INICIANDO PIPELINE DE GOBERNANZA Y MANTENIMIENTO CIA    "
echo "============================================================"
echo "Fecha y hora: $(date)"
echo

# ------------------------------------------------------------------------------
# 1. Comprobación de existencia y permisos de los scripts base
# ------------------------------------------------------------------------------
for script in "$SCRIPT_MANTENIMIENTO" "$SCRIPT_AUDITORIA"; do
    if [ ! -f "$script" ]; then
        echo "[ERROR CRÍTICO] No se encuentra el script requerido: $script"
        exit 1
    fi
    if [ ! -x "$script" ]; then
        echo "[AVISO] Asignando permisos de ejecución a $script..."
        chmod +x "$script"
    fi
done

# ------------------------------------------------------------------------------
# 2. Ejecución del Script 1: Mantenimiento (Integridad y Disponibilidad)
# ------------------------------------------------------------------------------
echo ">>> [FASE 1]: Ejecutando tareas de mantenimiento (sistema.sh)..."
if "$SCRIPT_MANTENIMIENTO"; then
    echo ">>> [FASE 1 OK]: Mantenimiento completado exitosamente."
else
    echo ">>> [FASE 1 FALLÓ]: Error en el volcado de BD o reportes de salud."
    exit 1
fi

echo
echo "------------------------------------------------------------"
echo

# ------------------------------------------------------------------------------
# 3. Ejecución del Script 2: Auditoría CIA y Privilegio Mínimo
# ------------------------------------------------------------------------------
echo ">>> [FASE 2]: Ejecutando auditoría de seguridad (verificar-permisos.sh)..."
if "$SCRIPT_AUDITORIA"; then
    echo
    echo "============================================================"
    echo "   RESULTADO FINAL: MANTENIMIENTO Y AUDITORÍA EXITOSOS      "
    echo "============================================================"
    exit 0
else
    echo
    echo "============================================================"
    echo "   RESULTADO FINAL: LA AUDITORÍA DE SEGURIDAD DETECTÓ FALLOS"
    echo "============================================================"
    exit 1
fi
