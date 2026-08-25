#!/bin/bash

# Detener el script si ocurre un error inesperado.
set -euo pipefail

BACKUP="/backups/notes_db.sql"
CONFIG="/opt/deploy-app/config/app.conf"
ERRORES=0

# INTEGRIDAD: comprobar que existe el backup y que no esta vacio.
echo "[INTEGRIDAD]"
if [ -s "$BACKUP" ]; then
    echo "OK: existe el backup $BACKUP"
else
    echo "ERROR: el backup no existe o esta vacio"
    ERRORES=$((ERRORES + 1))
fi

# CONFIDENCIALIDAD: comprobar propietario, grupo y permisos del archivo.
echo
echo "[CONFIDENCIALIDAD]"
# El directorio esta protegido. Docker permite consultar solamente los datos
# del archivo sin mostrar su contenido ni cambiar sus permisos.
DATOS=$(docker run --rm -v /:/host:ro alpine:3.22 \
    stat -c "%u:%g:%a" "/host$CONFIG" 2>/dev/null || true)

if [ -z "$DATOS" ]; then
    echo "ERROR: no existe $CONFIG"
    ERRORES=$((ERRORES + 1))
else
    IFS=: read -r PROPIETARIO GRUPO PERMISOS <<< "$DATOS"
    UID_ESPERADO=$(id -u devops-deploy)
    GID_ESPERADO=$(getent group deploy-team | cut -d: -f3)

    if [ "$PROPIETARIO" = "$UID_ESPERADO" ]; then
        echo "OK: propietario devops-deploy"
    else
        echo "ERROR: propietario incorrecto ($PROPIETARIO)"
        ERRORES=$((ERRORES + 1))
    fi

    if [ "$GRUPO" = "$GID_ESPERADO" ]; then
        echo "OK: grupo deploy-team"
    else
        echo "ERROR: grupo incorrecto ($GRUPO)"
        ERRORES=$((ERRORES + 1))
    fi

    if [ "$PERMISOS" = "600" ]; then
        echo "OK: permisos 600"
    else
        echo "ERROR: permisos incorrectos ($PERMISOS)"
        ERRORES=$((ERRORES + 1))
    fi
fi

# Mostrar el resultado final de la auditoria.
echo
if [ "$ERRORES" -eq 0 ]; then
    echo "AUDITORIA CIA: TODOS LOS CONTROLES PASARON"
else
    echo "AUDITORIA CIA: $ERRORES CONTROL(ES) FALLARON"
    exit 1
fi
