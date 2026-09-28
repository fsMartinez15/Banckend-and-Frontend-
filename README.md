# RideMove

## Entrega Angular + Spring Boot

El nuevo frontend web está en `frontend/`: Login, Registro y Dashboard, con
TypeScript estricto, JWT, configuración por entorno y pago visual de demostración.
Flutter sigue disponible como cliente móvil. Guía de arranque, matriz de requisitos,
SOLID, 12 factores, equipo e IDE: **[docs/ENTREGA.md](docs/ENTREGA.md)**.
Backlog Jira, Postman y pantallas para Figma: `output/entrega_angular_spring/`.

```powershell
./tools/start_backend.ps1
# En otra terminal:
./tools/start_frontend.ps1
```

Aplicación móvil Flutter para organizar solicitudes de transporte en Fusagasugá.
El backend Java 21 + Spring Boot implementa arquitectura hexagonal. Supabase
proporciona Auth y PostgreSQL con RLS y funciones transaccionales.

El núcleo está en `backend/src/main/java/co/ridemove/domain` y `application`.
No importa Spring ni Supabase. `RideService` implementa `RideUseCases` y recibe
puertos independientes de perfiles, viajes, vehículos y ubicación.

## Funciones incluidas

- Registro e inicio de sesión para pasajeros y conductores.
- Solicitud, cancelación, aceptación, inicio y finalización de viajes.
- Disponibilidad, vehículo y seguimiento del conductor en primer plano.
- Mapa del conductor con OpenStreetMap y atribución.
- Historial y calificación del servicio.
- Panel administrativo de usuarios, viajes y vehículos.
- Modo demostración sin credenciales para recorrer los tres roles.

## Ejecutar el modo demostración

```powershell
flutter run
```

Si no se entregan variables de Supabase, la app abre automáticamente el modo
demostración. Sus datos viven únicamente en memoria.

## Conectar Supabase

1. Crea un proyecto de Supabase.
2. En una base nueva ejecuta, en orden, ambas migraciones de `supabase/migrations`.
   En el proyecto conectado ya se aplicaron; no las ejecutes nuevamente.
3. Copia `config/supabase.example.json` como `config/supabase.json`.
4. Completa la URL, `API_BASE_URL` y la clave pública `publishable` o `anon`. Nunca uses la
   clave `service_role` dentro de la aplicación.
5. Compila el backend con Java 21 y Maven, e inícialo:

```powershell
mvn -f backend/pom.xml verify
./tools/start_backend.ps1
```

El script lee el archivo local e inicia `backend/target/ridemove-api-2.0.0.jar`.
También puedes definir `SUPABASE_URL` y `SUPABASE_ANON_KEY` como variables de
entorno y ejecutar el JAR directamente. No requiere la contraseña de PostgreSQL.

6. Inicia la app con:

```powershell
flutter run --dart-define-from-file=config/supabase.json
```

Para generar un APK:

```powershell
flutter build apk --release --dart-define-from-file=config/supabase.json
```

El archivo real `config/supabase.json` está ignorado por Git.

`API_BASE_URL=http://10.0.2.2:8080` conecta un emulador Android al equipo anfitrión.
Para un teléfono físico usa la IP LAN del equipo y el puerto del backend.
Para producción publica la API con HTTPS y cambia esta URL antes de compilar.
El HTTP sin cifrar está permitido solo en la variante Android de depuración.
El backend aún no está desplegado públicamente.

Para previsualizar en web usa `--dart-define=API_BASE_URL=http://localhost:8080`
y `--web-port=7357`; incluye ese origen en `CORS_ORIGINS` dentro de `backend/.env`.
Los orígenes se separan por comas. Para desplegar Java puede
usarse el `backend/Dockerfile` en un alojamiento de contenedores.

## Primer administrador

Registra una cuenta normalmente y cambia su rol una sola vez desde el SQL
Editor, sustituyendo el correo:

```sql
update public.profiles
set role = 'admin'
where id = (select id from auth.users where email = 'admin@ejemplo.com');
```

## Estructura

- `backend/.../domain`: entidades y reglas independientes de frameworks.
- `backend/.../application`: casos de uso, puertos de entrada y salida.
- `backend/.../adapter`: entrada REST y salida Supabase HTTP.
- `backend/.../bootstrap`: composición y autenticación de la API.
- `lib/main.dart`: composición de adaptadores del cliente móvil.
- `lib/presentation`: pantallas y mapa.
- `lib/application`: seguimiento GPS independiente de los SDK.
- `lib/domain`: contratos del cliente; sus mapas son DTO de transporte, no el dominio Java.
- `lib/data`: adaptadores HTTP, GPS y demostración.
- `supabase/migrations`: esquema, restricciones, RLS y RPC.
- `test` y `backend/src/test`: pruebas móviles, de negocio, HTTP y arquitectura.
- `output/documentos_corregidos`: informe y comité corregidos en PDF.

## Interfaz móvil

El inicio muestra un mapa mundial interactivo, centrado inicialmente en
Fusagasugá, con controles de zoom, vista del mundo y centrado. El pasajero tiene
una tarjeta deslizable, accesos a destinos frecuentes
y un formulario de recorrido con validación e intercambio de origen y destino.
La paleta combina azul eléctrico, azul noche y naranja.

El marcador de la ciudad es una referencia, no la ubicación GPS del pasajero.
Cuando hay un viaje aceptado/en curso y el conductor comparte su ubicación,
el inicio muestra su último punto disponible. Los mapas usan OpenStreetMap,
requieren conexión y ofrecen reintento si las imágenes no cargan. El formulario
y el historial siguen disponibles ante un fallo del mapa.

Al iniciar un viaje como conductor se calcula y dibuja automáticamente un
recorrido por carretera dentro de RideMove: línea azul, origen A, destino B,
distancia, duración estimada e indicaciones en español. El mapa encuadra la ruta
y tiene un botón para volver a verla completa. Se puede reabrir desde
«Abrir navegación». Los nombres ambiguos permiten elegir un resultado; también
se pueden corregir ambos puntos tocando el mapa. «Recalcular desde mi ubicación»
usa una nueva lectura de GPS. La ruta no se recalcula sola al desviarse; el tiempo
mostrado corresponde al recorrido calculado, sin tráfico en vivo ni cuenta atrás.

El puerto `RoutePlanner` separa el mapa del adaptador HTTP: [Photon](https://github.com/komoot/photon)
resuelve lugares y [OSRM](https://project-osrm.org/docs/v5.24.0/api/) calcula la
geometría por calles y los pasos. Hay caché en memoria, peticiones serializadas,
intervalo mínimo de 1,1 segundos, tiempo límite y reintento explícito. Nunca se
sustituye un fallo del motor por una línea recta. «Parque principal» se consulta
como Plaza Mayor de Fusagasugá; los lugares se resuelven al abrir la navegación,
y las correcciones de puntos permanecen durante esa pantalla.

Los endpoints públicos se usan para este piloto académico y requieren Internet;
no garantizan disponibilidad. El [servidor demo de OSRM](https://github.com/Project-OSRM/osrm-backend/wiki/Demo-server)
es para uso razonable no comercial. Para operación comercial o más usuarios,
configura instancias propias/contratadas mediante `GEOCODER_URL` y `ROUTER_URL`
al compilar. Las consultas transmiten nombres de lugares a Photon y coordenadas
del recorrido a OSRM, sin credenciales ni perfiles de Supabase. No se usa la API
pública de Nominatim en la aplicación.

El botón opcional «Navegar con Waze» usa el
[enlace oficial de Waze](https://developers.google.com/waze/deeplinks) para voz.
Al salir a Waze el seguimiento de RideMove se pausa, y se reactiva con el botón
GPS al regresar. La apertura de Waze requiere verificación en un teléfono físico.

## Verificación

```powershell
flutter analyze
flutter test
dart run tools/check_route.dart # Prueba manual por red entre dos lugares públicos
mvn -f backend/pom.xml verify
```

`supabase/tests/workflow.sql` contiene una prueba transaccional para ejecutar con
psql conectado al proyecto. Crea identidades temporales, comprueba el flujo y RLS,
y termina con ROLLBACK. No guarda usuarios ni viajes de prueba.

La ubicación se activa después de aceptar un viaje, se actualiza al desplazarse
y se detiene cuando la aplicación deja el primer plano. Al volver, el conductor
debe activarla de nuevo. El refresco del pasajero es cada 10 segundos. Quedan
pendientes pruebas de GPS en teléfono físico, medición del objetivo de 3 segundos
y carga concurrente. iOS requiere compilación y firma en macOS.
