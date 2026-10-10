# San Martín ERP

ERP web estático con Supabase para autenticación, base de datos, Storage y Edge Functions. El navegador usa una **clave publicable**; las claves administrativas y de correo sólo deben estar en los secretos de Supabase.

## Estructura

| Ruta | Propósito |
| --- | --- |
| `index.html` y `*.js` | Interfaz, operaciones y acceso. |
| `supabase/baseline/20261009_post_etapa_b.sql` | Esquema completo capturado tras la Etapa B: 44 tablas, 75 funciones, vistas, restricciones, índices, RLS, grants, triggers, seis buckets y semillas de roles/permisos. |
| `supabase/migrations/20261009184222_etapa_b_h10_h14.sql` | Historial reproducible de la Etapa B para actualizar una instalación que ya tenía la Etapa A. Ya está aplicada al proyecto actual. |
| `supabase/migrations/20261009184808_etapa_b_rol_activo.sql` | Ajuste posterior de B: también desactiva el acceso cuando el rol del usuario está inactivo. Ya está aplicado al proyecto actual. |
| `supabase/migrations/20261009185206_etapa_b_cliente_sin_rol.sql` | Conserva el acceso de clientes activos sin rol ERP y mantiene el bloqueo de roles desactivados. Ya está aplicada al proyecto actual. |
| `supabase/migrations/20261009185850_etapa_b_imagen_url_portable.sql` | Valida la URL de cada imagen contra el proyecto que emitió el token, para permitir instalaciones nuevas. Ya está aplicada al proyecto actual. |
| `supabase/functions/manage-users/` y `supabase/functions/stock-alerts/` | Funciones de servidor. |
| `tests/` | Pruebas locales sin datos reales. |

El esquema base incluye las definiciones que faltaban en la copia inicial: `registrar_movimiento_inventario`, `tiene_permiso`, `tiene_acceso_ubicacion` y sus dependencias. Está pensado para un **proyecto Supabase nuevo** con Auth y Storage ya creados por Supabase. Es una captura de estructura y permisos, no una copia de datos: no contiene usuarios de Auth, perfiles, ventas, existencias, configuración de empresa ni archivos de Storage. Para restaurar una operación existente se requiere, además, respaldo de datos y archivos.

La captura se hizo el 9 de octubre de 2026 sobre PostgreSQL 17 del proyecto `beasfybalepkdlomzazf`. El manifiesto con cantidades y dependencias está en `supabase/baseline/manifest.json`. Queda un solo disparador de alta de usuario, `al_crear_usuario_perfil`. Los roles `anon` y `authenticated` no tienen `TRUNCATE` sobre las tablas de negocio.

## Instalar o actualizar la base

**Proyecto actual:** las Etapas A y B, incluidos los dos ajustes de acceso y el ajuste de URL de imágenes, ya están aplicadas. `manage-users` y `stock-alerts` también están desplegadas. No ejecutes de nuevo el esquema base ni esas migraciones. Para poner la nueva interfaz a disposición de los usuarios, publica los archivos web en el hosting que uses.

**Proyecto nuevo:**

1. Crea un proyecto Supabase con Auth y Storage habilitados. Conserva aparte la URL y la clave publicable del proyecto.
2. Ejecuta `supabase/baseline/20261009_post_etapa_b.sql` una sola vez como administrador de la base. Este archivo **ya incluye** las Etapas A y B; no ejecutes sus migraciones después.
3. Crea el primer usuario en Supabase Auth. El trigger crea su perfil; asigna a ese perfil el rol `ADMINISTRADOR` desde SQL Editor, por ejemplo:
   ```sql
   update public.perfiles
   set rol_id=(select id from public.roles where codigo='ADMINISTRADOR'),
       activo=true, estado='ACTIVO'
   where id='<UUID DEL USUARIO DE AUTH>'::uuid;
   ```
4. Configura las URL permitidas de Auth para el dominio final del ERP y los enlaces de invitación/recuperación. Ajusta la URL y la clave publicable del frontend para el proyecto nuevo. Despliega `manage-users` y `stock-alerts`.
5. Configura `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` para las funciones; para alertas por correo, `RESEND_API_KEY`, `ALERT_EMAIL_TO` y `ALERT_EMAIL_FROM`. `ALERT_DISPATCH_SECRET` es opcional si usas un proceso de servicio. Mantén esos valores fuera del navegador y del repositorio.

Las políticas de `storage.objects` están versionadas en la base, pero los **archivos** no se recrean con SQL. En un proyecto nuevo, sube los archivos necesarios a los buckets creados por el esquema base. Una instalación vacía puede iniciar sin imágenes ni inventario. La publicación del sitio web no despliega automáticamente las Edge Functions.

## SQL anterior

Si conservas archivos `supabase_*.sql` de copias anteriores, así como `corregir_pago_ecommerce_cantidad.sql`, trátalos como antecedentes de desarrollo. Sus definiciones se consolidaron en el esquema base y las migraciones. **No los ejecutes sobre el proyecto actual ni sobre una instalación del esquema base.** En particular, `supabase_configuracion_erp.sql`, `supabase_facturas_ecommerce.sql` y `supabase_ordenes_compra.sql` contienen definiciones anteriores a la Etapa B y podrían revertirla. Los archivos de `supabase/sql/estabilizacion/` son fragmentos de revisión que alimentan las migraciones, no pasos adicionales de instalación.

Para actualizar una instalación que ya tenía A, ejecuta en este orden `supabase/migrations/20261009184222_etapa_b_h10_h14.sql`, `supabase/migrations/20261009184808_etapa_b_rol_activo.sql`, `supabase/migrations/20261009185206_etapa_b_cliente_sin_rol.sql` y `supabase/migrations/20261009185850_etapa_b_imagen_url_portable.sql`. La migración `supabase/migrations/20261009135451_estabilizacion_h01_h09_20261009.sql` corresponde a A. El esquema base final incluye las cinco. Para una base creada antes de A, planifica una migración según su estado particular; el esquema base presupone una instalación nueva.

## Pruebas y ejecución local

Se necesita Node.js 22 o superior para las pruebas y Python 3 para el ejemplo de servidor local. Las dependencias de prueba están fijadas en `package-lock.json`.

```sh
npm ci
npm test
python -m http.server 8000
```

Abre `http://localhost:8000`. Las pruebas usan PGlite y simulaciones de la interfaz; no escriben en Supabase. Comprueban reconstrucción del esquema final, la migración B sobre una captura de A, procesos de venta/reserva/Kardex/transferencia/devolución, permisos, imágenes, CSV, documentos, invitaciones y recepción de compras. Después de actualizar una dependencia del navegador o una función, repite `npm test` y una prueba manual de inicio de sesión, compra y devolución en un entorno de prueba.

## Revisión pendiente

Los avisos de Supabase Advisors del 9 de octubre de 2026 aún incluyen tres vistas `SECURITY DEFINER` del catálogo, dos funciones sin `search_path` fijo, diez funciones definidoras invocables por `anon`, una configuración de protección de contraseñas filtradas y cuatro tablas con RLS sin política. Los avisos de rendimiento incluyen 40 claves foráneas sin índice, 33 índices sin uso, diez conjuntos de políticas múltiples, cinco evaluaciones repetidas de Auth en RLS y un índice duplicado. Requieren una revisión separada de uso y permisos antes de cambiarlos.

En el bucket `productos` se detectaron tres archivos anteriores sin fila en `producto_imagenes`. La Etapa B no los borra automáticamente; comprueba manualmente si los usa otra página antes de eliminarlos.

## Publicación del frontend

La carpeta contiene `.github/workflows/pages.yml` para GitHub Pages. El workflow publica sólo el sitio estático. Sube los archivos a la raíz del repositorio, deja `index.html` en esa raíz, configura GitHub Pages para GitHub Actions y ejecuta el workflow. Las funciones y la base permanecen en Supabase. Para otro hosting estático, publica la misma carpeta sin `tests/` ni archivos SQL si prefieres un artefacto pequeño.

Configura en Supabase Authentication las redirecciones permitidas del dominio final antes de probar invitaciones o recuperación. La clave publicable del frontend puede mostrarse al usuario; la autorización real se aplica en las políticas RLS y RPC. [Guía de redirecciones de Auth](https://supabase.com/docs/guides/auth/redirect-urls) y [control de acceso de Storage](https://supabase.com/docs/guides/storage/security/access-control).
