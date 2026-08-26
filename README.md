# TP 13 - Gobernanza de Procesos y Tríada CIA

**Asignatura:** DevSecOps  
**Carrera:** Licenciatura en Ciberseguridad — Universidad Nacional de Hurlingham (UNAHUR)  

---

## Enunciado del Trabajo Práctico

**Tarea:** El alumno deberá fortalecer los scripts de automatización base de la Notes App. Deberá implementar un script de mantenimiento que asegure la disponibilidad del sistema, realizar un análisis manual con OWASP ZAP para detectar fallos de configuración iniciales y configurar un entorno de ejecución local que respete el principio de privilegio mínimo.

---

## 1. Resumen Ejecutivo y Objetivos

Este trabajo práctico marca la transición formativa desde una administración operativa tradicional hacia un enfoque integral de **Seguridad por Diseño (*Security by Design*)**. A través del fortalecimiento de los scripts de automatización de la *Notes App*, se asientan bases de gobernanza técnica alineadas con la **Tríada CIA** y el **Principio de Privilegio Mínimo**:

* **Confidencialidad:** Aislamiento de configuraciones sensibles y ejecución de despliegues desacoplada del usuario administrador (`root`).
* **Integridad:** Automatización de respaldos consistentes de base de datos con manejo defensivo de errores (`set -euo pipefail`) para prevenir volcados corruptos o vacíos.
* **Disponibilidad:** Recolección periódica y estructurada de telemetría del sistema (CPU, carga y almacenamiento) para anticipar fallas por agotamiento de recursos.
* **Análisis Dinámico (DAST):** Exploración de caja negra con OWASP ZAP para detectar configuraciones inseguras y omisión de cabeceras HTTP antes de avanzar en el pipeline.

---

## 2. Desarrollo Técnico por Pasos y Justificación del Robustecimiento

### Paso 1: Automatización para la Disponibilidad e Integridad (`sistema.sh`)
Se implementó el script de mantenimiento encargado de respaldar la base de datos PostgreSQL (`notesdb`) mediante `pg_dump` y registrar telemetría del sistema en `/backups/reportes/`.

En cuanto a su robustecimiento, la versión base utilizaba una ruta relativa fija (`--project-directory app`), lo que provocaba una falla crítica de ejecución si el operador corría la rutina fuera del directorio previsto. La versión mejorada parametriza la ubicación mediante la variable absoluta `COMPOSE_DIR="/home/alumno/Operaciones-1-guia-hecha/guia-06"`, otorgando determinismo al script para tareas interactivas o desatendidas (`cron`). Asimismo, la incorporación de `set -euo pipefail` previene que fallos intermedios generen volcados corruptos, y las funciones de telemetría de CPU y disco agrupan las métricas bajo encabezados estandarizados con marcas temporales para simplificar auditorías.

### Paso 2: Análisis Manual de Seguridad DAST (OWASP ZAP)
Con la aplicación activa localmente, se desplegó OWASP ZAP (v2.17.0 bajo OpenJDK 17) en `$HOME/.local/opt` y se realizó una exploración manual (*Manual Explore*) interactuando con las rutas del frontend y la API REST.

Durante la auditoría de caja negra se identificaron alertas de seguridad relevantes:
* *Missing Anti-clickjacking Header (Media):* Ausencia de `X-Frame-Options` o `Content-Security-Policy: frame-ancestors`. *Mitigación:* Configurar en el servidor web `X-Frame-Options: SAMEORIGIN` o `DENY`.
* *Content-Security-Policy (CSP) Header Not Set (Media):* Falta de directivas restrictivas contra Cross-Site Scripting (XSS). *Mitigación:* Definir una política `Content-Security-Policy: default-src 'self'`.
* *X-Content-Type-Options Header Missing (Baja):* Exposición a MIME-sniffing. *Mitigación:* Inyectar `X-Content-Type-Options: nosniff` en todas las respuestas HTTP.

### Paso 3: Confidencialidad y Principio de Privilegio Mínimo
Se restringió el acceso a nivel de sistema operativo para que las operaciones de despliegue no dependan del superusuario `root`. Para ello, se creó el usuario no privilegiado `devops-deploy` perteneciente al grupo `deploy-team` y se protegió el archivo sensible `/opt/deploy-app/config/app.conf` asignándole propiedad exclusiva y permisos octales estrictos `600` (`-rw-------`), impidiendo que otros usuarios locales puedan visualizar credenciales.

### Paso 4: Script de Auditoría de la Tríada CIA (`verificar-permisos.sh`)
Se diseñó el script de control automatizado encargado de validar las aserciones de seguridad implementadas en los pasos previos.

Respecto a las mejoras aplicadas sobre este script, el código inicial asumía un entorno estático invocando directamente las consultas de usuario y grupo, lo que arrojaba variables vacías si el aprovisionamiento aún no se había completado. La versión robustecida incorpora una verificación temprana que valida la presencia de `devops-deploy` y `deploy-team` en el sistema antes de evaluar los permisos. Además, solventa la dependencia rígida del contenedor de Docker implementando una degradación elegante (*fallback*) mediante el comando nativo `stat` de Linux, evaluando la integridad del backup (`[ -s "$BACKUP" ]`) y retornando códigos de salida POSIX estándar (`exit 0` en éxito y `exit 1` en error).

### Orquestación de Procesos (`orquestar-mantenimiento-auditoria.sh`)
Para unificar y automatizar el ciclo de gobernanza, se implementó un script orquestador maestro que ejecuta de punta a punta las dos fases principales:
1. **Fase Operativa:** Ejecuta `sistema.sh` asegurando la persistencia y salud del servicio.
2. **Fase de Auditoría (*Quality Gate*):** Invoca `verificar-permisos.sh` validando inmediatamente el cumplimiento de la Tríada CIA.

---

## 3. Salida de Validación del Pipeline Orquestado

```text
$ ./orquestar-mantenimiento-auditoria.sh
============================================================
    INICIANDO PIPELINE DE GOBERNANZA Y MANTENIMIENTO CIA    
============================================================
Fecha y hora: mié 26 ago 2026 19:39:42 -03

>>> [FASE 1]: Ejecutando tareas de mantenimiento (sistema.sh)...
Iniciando tareas de mantenimiento del sistema...
Creando backup de la base de datos...
Backup generado exitosamente en /backups/notes_db.sql
Generando reporte de CPU...
Reporte de CPU guardado en /backups/reportes/cpu-20260826-193942.txt
Generando reporte de disco...
Reporte de disco guardado en /backups/reportes/disco-20260826-193942.txt
Mantenimiento terminado correctamente.
>>> [FASE 1 OK]: Mantenimiento completado exitosamente.

------------------------------------------------------------

>>> [FASE 2]: Ejecutando auditoría de seguridad (verificar-permisos.sh)...
[INTEGRIDAD]
OK: existe el backup /backups/notes_db.sql con tamaño mayor a 0 bytes

[CONFIDENCIALIDAD]
OK: propietario devops-deploy (UID: 1001)
OK: grupo deploy-team (GID: 1002)
OK: permisos 600 (-rw-------)

============================================================
   RESULTADO FINAL: MANTENIMIENTO Y AUDITORÍA EXITOSOS      
============================================================
