# TP 13 - Gobernanza de Procesos y Tríada CIA

**Asignatura:** DevSecOps  
**Carrera:** Licenciatura en Ciberseguridad — Universidad Nacional de Hurlingham (UNAHUR)  

---

## 1. Resumen Ejecutivo y Objetivos

Este trabajo práctico implementa la transición formativa desde una administración operativa tradicional hacia un enfoque integral de **Seguridad por Diseño (*Security by Design*)**. A través del fortalecimiento de los scripts de automatización de la *Notes App*, se asientan bases de gobernanza técnica alineadas con la **Tríada CIA** y el **Principio de Privilegio Mínimo**:

* **Confidencialidad:** Aislamiento de configuraciones sensibles y ejecución de despliegues desacoplada del usuario administrador (`root`).
* **Integridad:** Automatización de respaldos consistentes de base de datos con manejo defensivo de errores (`set -euo pipefail`) para prevenir volcados corruptos o vacíos.
* **Disponibilidad:** Recolección periódica y estructurada de telemetría del sistema (CPU, carga y almacenamiento) para anticipar fallas por agotamiento de recursos.
* **Análisis Dinámico (DAST):** Exploración de caja negra con OWASP ZAP para detectar configuraciones inseguras y omisión de cabeceras HTTP antes de avanzar en el pipeline.

---

## 2. Desarrollo Detallado por Pasos y Robustecimiento

### Paso 1: Automatización para la Disponibilidad e Integridad (`sistema.sh`)
* **Implementación:** Se configuró un script modular en Bash que gestiona la persistencia de la base de datos PostgreSQL (`notesdb`) mediante `pg_dump` y almacena reportes periódicos en `/backups/reportes/`.
* **Robustecimiento y Justificación Técnica:**
  * **Ejecución Determinista:** Se reemplazó la ruta relativa original (`--project-directory app`) por la variable absoluta `COMPOSE_DIR="/home/alumno/Operaciones-1-guia-hecha/guia-06"`. Esto evita fallos (`no configuration file provided: not found`) y asegura que el script funcione desde cualquier ubicación o mediante tareas desatendidas (`cron`).
  * **Integridad y Manejo Defensivo de Errores:** La directiva `set -euo pipefail` interrumpe inmediatamente el flujo si el servicio `db` está detenido o si la redirección falla por permisos, impidiendo la generación de archivos `.sql` corruptos o vacíos.
  * **Disponibilidad y Trazabilidad:** Las funciones `reporte_cpu` y `reporte_disco` agrupan las métricas de `uptime`, `lscpu` y `df -h` bajo cabeceras estandarizadas con marcas temporales, simplificando la auditoría manual y la ingesta de telemetría.

### Paso 2: Análisis Manual de Seguridad DAST (OWASP ZAP)
* **Implementación:** Con la aplicación activa localmente, se desplegó OWASP ZAP (v2.17.0 bajo OpenJDK 17) en `$HOME/.local/opt` y se realizó una exploración manual (*Manual Explore*) interactuando con los endpoints del frontend y la API REST.
* **Alertas Detectadas y Mitigaciones:**
  * *Missing Anti-clickjacking Header (Media):* Ausencia de `X-Frame-Options` o `Content-Security-Policy: frame-ancestors`. *Mitigación:* Configurar en el proxy inverso o middleware `X-Frame-Options: SAMEORIGIN`.
  * *Content-Security-Policy (CSP) Header Not Set (Media):* Ausencia de directivas restrictivas contra Cross-Site Scripting (XSS). *Mitigación:* Definir una política `Content-Security-Policy: default-src 'self'`.
  * *X-Content-Type-Options Header Missing (Baja):* Exposición a MIME-sniffing. *Mitigación:* Inyectar la cabecera `X-Content-Type-Options: nosniff` en todas las respuestas del servidor web.

### Paso 3: Confidencialidad y Principio de Privilegio Mínimo
* **Implementación:** Se restringió el acceso a nivel de sistema operativo para que las operaciones de despliegue no dependan de `root`.
* **Controles Aplicados:**
  * Creación del usuario sin privilegios `devops-deploy` y su asignación al grupo `deploy-team`.
  * Creación del archivo sensible `/opt/deploy-app/config/app.conf` con propietario `devops-deploy:deploy-team` y permisos octales estrictos `600` (`-rw-------`). Ningún otro usuario no autorizado del sistema tiene permisos de lectura o escritura sobre este archivo.

### Paso 4: Script de Auditoría de la Tríada CIA (`verificar-permisos.sh`)
* **Implementación:** Se diseñó el script de control automatizado que valida las aserciones de seguridad implementadas en los pasos previos.
* **Robustecimiento y Justificación Técnica:**
  * **Validación Temprana de Cuentas:** Comprueba previamente la existencia de `devops-deploy` y `deploy-team` en el sistema (`id` y `getent`), abortando con un error descriptivo si el aprovisionamiento no se completó, evitando variables vacías.
  * **Tolerancia a Fallos en Inspección (Fallback):** En entornos Linux donde Docker no esté disponible o el usuario no pertenezca al socket `docker`, el script degrada controladamente hacia la lectura nativa con el comando `stat`, evitando falsos errores de archivo inexistente.
  * **Validación de Integridad y Salida Estandarizada:** Evalúa que el respaldo exista y tenga contenido real (`[ -s "$BACKUP" ]`), arrojando códigos de retorno POSIX (`exit 0` en éxito y `exit 1` en fallo) para integrarse como *Quality Gate* en pipelines CI/CD.

---

## 3. Salida de Validación del Script de Auditoría

```text
$ ./verificar-permisos.sh
[INTEGRIDAD]
OK: existe el backup /backups/notes_db.sql con tamaño mayor a 0 bytes

[CONFIDENCIALIDAD]
OK: propietario devops-deploy (UID: 1001)
OK: grupo deploy-team (GID: 1002)
OK: permisos 600 (-rw-------)

AUDITORIA CIA: TODOS LOS CONTROLES PASARON
