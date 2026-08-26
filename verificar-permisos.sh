#!/bin/bash
# ==============================================================================
# TP 13 - Auditoría Automatizada de Seguridad (Tríada CIA)
# Archivo: verificar-permisos.sh
# Objetivo: Validar de manera determinista y segura los controles de 
#           Integridad (backup) y Confidencialidad (privilegio mínimo).
# ==============================================================================

set -euo pipefail

BACKUP="/backups/notes_db.sql"
CONFIG="/opt/deploy-app/config/app.conf"
USUARIO_ESPERADO="devops-deploy"
GRUPO_ESPERADO="deploy-team"
ERRORES=0

# ------------------------------------------------------------------------------
# 1. Pre-verificación de Dependencias y Cuentas del Sistema
# ------------------------------------------------------------------------------
if ! id "$USUARIO_ESPERADO" &>/dev/null; then
    echo "[CRÍTICO] El usuario '$USUARIO_ESPERADO' no existe en el sistema."
    exit 1
fi

if ! getent group "$GRUPO_ESPERADO" &>/dev/null; then
    echo "[CRÍTICO] El grupo '$GRUPO_ESPERADO' no existe en el sistema."
    exit 1
fi

UID_ESPERADO=$(id -u "$USUARIO_ESPERADO")
GID_ESPERADO=$(getent group "$GRUPO_ESPERADO" | cut -d: -f3)

# ------------------------------------------------------------------------------
# 2. Control de Integridad (Backup de Base de Datos)
# ------------------------------------------------------------------------------
echo "[INTEGRIDAD]"
if [ -s "$BACKUP" ]; then
    echo "OK: existe el backup $BACKUP con tamaño mayor a 0 bytes"
else
    echo "ERROR: el backup no existe o está vacío"
    ERRORES=$((ERRORES + 1))
fi

# ------------------------------------------------------------------------------
# 3. Control de Confidencialidad y Privilegio Mínimo
# ------------------------------------------------------------------------------
echo
echo "[CONFIDENCIALIDAD]"

# Extracción de metadatos (UID, GID, Permisos Octales) sin alterar el archivo
if command -v docker &>/dev/null && docker info &>/dev/null; then
    DATOS=$(docker run --rm -v /:/host:ro alpine:3.22 \
        stat -c "%u:%g:%a" "/host$CONFIG" 2>/dev/null || true)
else
    DATOS=$(stat -c "%u:%g:%a" "$CONFIG" 2>/dev/null || true)
fi

if [ -z "$DATOS" ]; then
    echo "ERROR: no existe el archivo $CONFIG"
    ERRORES=$((ERRORES + 1))
else
    IFS=: read -r PROPIETARIO GRUPO PERMISOS <<< "$DATOS"

    if [ "$PROPIETARIO" = "$UID_ESPERADO" ]; then
        echo "OK: propietario $USUARIO_ESPERADO (UID: $PROPIETARIO)"
    else
        echo "ERROR: propietario incorrecto ($PROPIETARIO, esperado: $UID_ESPERADO)"
        ERRORES=$((ERRORES + 1))
    fi

    if [ "$GRUPO" = "$GID_ESPERADO" ]; then
        echo "OK: grupo $GRUPO_ESPERADO (GID: $GRUPO)"
    else
        echo "ERROR: grupo incorrecto ($GRUPO, esperado: $GID_ESPERADO)"
        ERRORES=$((ERRORES + 1))
    fi

    if [ "$PERMISOS" = "600" ]; then
        echo "OK: permisos 600 (-rw-------)"
    else
        echo "ERROR: permisos octales incorrectos ($PERMISOS, esperado: 600)"
        ERRORES=$((ERRORES + 1))
    fi
fi

# ------------------------------------------------------------------------------
# 4. Evaluación Final de la Auditoría
# ------------------------------------------------------------------------------
echo
if [ "$ERRORES" -eq 0 ]; then
    echo "AUDITORIA CIA: TODOS LOS CONTROLES PASARON"
    exit 0
else
    echo "AUDITORIA CIA: $ERRORES CONTROL(ES) FALLARON"
    exit 1
fi

