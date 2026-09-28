import { mkdir, writeFile } from 'node:fs/promises';
const out = 'output/entrega_angular_spring';
for (const folder of ['postman', 'figma', 'jira']) await mkdir(`${out}/${folder}`, { recursive: true });
const save = (path, value) => writeFile(`${out}/${path}`, JSON.stringify(value, null, 2) + '\n');
const test = lines => [{ listen: 'test', script: { type: 'text/javascript', exec: lines } }];
const codeTest = code => `pm.test('HTTP ${code}', () => pm.response.to.have.status(${code}));`;
const sessionTests = [codeTest(200), 'const session = pm.response.json();', "pm.test('JWT recibido', () => pm.expect(session.access_token).to.be.a('string').and.not.empty);", "if (session.access_token) pm.environment.set('accessToken', session.access_token);", "if (session.refresh_token) pm.environment.set('refreshToken', session.refresh_token);"];
function request(name, method, path, description, body, status = 200, auth = undefined, lines = undefined) {
  const req = { method, header: body ? [{ key: 'Content-Type', value: 'application/json' }] : [], url: `{{baseUrl}}${path}`, description };
  if (auth) req.auth = auth;
  if (body) req.body = { mode: 'raw', raw: JSON.stringify(body, null, 2), options: { raw: { language: 'json' } } };
  return { name, request: req, event: test(lines ?? [codeTest(status)]) };
}
const noAuth = { type: 'noauth' };
const collection = {
  info: { name: 'RideMove · Angular + Spring Boot', schema: 'https://schema.getpostman.com/json/collection/v2.1.0/collection.json', description: 'REST/JSON con JWT Supabase. Configura el entorno local. La carpeta de escritura modifica la BD: usar cuentas de prueba y ejecutar peticiones individualmente. El pago frontend es solo demo y no tiene endpoint.' },
  auth: { type: 'bearer', bearer: [{ key: 'token', value: '{{accessToken}}', type: 'string' }] },
  item: [
    { name: '01 · Salud y seguridad sin sesión', item: [
      request('Salud pública', 'GET', '/health', 'Servicio disponible; no comprueba por sí solo la conexión a BD.', null, 200, noAuth),
      request('Viajes sin JWT → 401', 'GET', '/api/trips', 'Verifica que no se puede leer el negocio sin autenticación.', null, 401, noAuth),
      request('JWT manipulado → 401', 'GET', '/api/profile', 'Debe ser rechazado antes de acceder a Supabase.', null, 401, { type: 'bearer', bearer: [{ key: 'token', value: 'invalid.jwt.token', type: 'string' }] }),
      request('Registro admin rechazado → 409', 'POST', '/api/auth/register', 'Validación local del caso de uso; no crea cuentas.', { email: 'invalid-admin@example.org', password: 'example-password', name: 'Prueba admin', role: 'admin' }, 409, noAuth)
    ] },
    { name: '02 · Sesión (cuenta de prueba)', item: [
      request('Iniciar sesión', 'POST', '/api/auth/login', 'Usa email y password de una cuenta existente. Guarda tokens en el entorno activo.', { email: '{{email}}', password: '{{password}}' }, 200, noAuth, sessionTests),
      request('Renovar JWT', 'POST', '/api/auth/refresh', 'Reemplaza también el refresh token retornado.', { refreshToken: '{{refreshToken}}' }, 200, noAuth, sessionTests),
      request('Cerrar sesión', 'POST', '/api/auth/logout', 'Revoca la sesión de renovación. Un access token puede vivir hasta su expiración.', {}, 204, undefined, [codeTest(204), "pm.environment.unset('accessToken');", "pm.environment.unset('refreshToken');"])
    ] },
    { name: '03 · Dashboard y consultas', item: [
      request('Mi perfil', 'GET', '/api/profile', 'Devuelve el perfil autenticado; guarda userId.', null, 200, undefined, [codeTest(200), "pm.environment.set('userId', pm.response.json().id);"]),
      request('Viajes visibles', 'GET', '/api/trips', 'Filtrado por actor y RLS. No permite acceder al historial de otros pasajeros.', null, 200, undefined, [codeTest(200), "pm.test('Lista tipada', () => pm.expect(pm.response.json()).to.be.an('array'));"]),
      request('Perfiles visibles', 'GET', '/api/profiles', 'La visibilidad depende del rol y RLS.'),
      request('Vehículos visibles', 'GET', '/api/vehicles', 'Devuelve vehículos visibles al usuario autenticado.'),
      request('Ubicaciones visibles', 'GET', '/api/locations', 'Datos autorizados por rol y viaje.')
    ] },
    { name: '04 · Escritura manual en datos de prueba', description: 'Estas peticiones crean cuentas o modifican datos reales del ambiente elegido. No ejecutar en bloque sobre usuarios reales.', item: [
      request('Registrar cuenta', 'POST', '/api/auth/register', 'Puede requerir confirmación de correo. Ejecuta una vez con una cuenta de prueba controlada.', { name: '{{name}}', email: '{{email}}', password: '{{password}}', role: '{{registrationRole}}' }, 201, noAuth, [codeTest(201), 'const session = pm.response.json();', "if (session.access_token) pm.environment.set('accessToken', session.access_token);", "if (session.refresh_token) pm.environment.set('refreshToken', session.refresh_token);"]),
      request('Solicitar viaje', 'POST', '/api/trips', 'Pasajero activo sin otro viaje activo. Respuesta 201 sin cuerpo. Consulta Viajes visibles y copia el id creado a tripId.', { origin: '{{origin}}', destination: '{{destination}}' }, 201),
      request('Cambiar estado', 'PUT', '/api/trips/{{tripId}}/status', 'pending→accepted (conductor disponible), accepted→in_progress→completed (conductor asignado), pending→cancelled (pasajero autor).', { status: '{{targetStatus}}' }),
      request('Rechazar viaje', 'POST', '/api/trips/{{tripId}}/rejections', 'Conductor; no cancela el viaje para los demás conductores.', {}),
      request('Calificar', 'POST', '/api/trips/{{tripId}}/rating', 'Pasajero autor, viaje completado, una sola vez.', { rating: 5, comment: 'Prueba de aceptación' }),
      request('Actualizar mi perfil', 'PUT', '/api/profile', 'Solo nombre y teléfono del actor.', { name: '{{name}}', phone: '{{phone}}' }),
      request('Activar disponibilidad', 'PUT', '/api/availability', 'Conductor activo, sujeto a reglas de vehículo y viaje.', { available: true }),
      request('Guardar vehículo', 'PUT', '/api/vehicle', 'Conductor: completa valores de prueba y userId desde Mi perfil.', { driver_id: '{{userId}}', plate: '{{plate}}', brand: '{{brand}}', model: '{{model}}', color: '{{color}}', license: '{{license}}' }),
      request('Enviar ubicación', 'PUT', '/api/location', 'Conductor disponible. Coordenadas públicas de ejemplo en Fusagasugá.', { latitude: 4.3365, longitude: -74.3638 }),
      request('Suspender usuario de prueba', 'PUT', '/api/profiles/{{targetUserId}}/access', 'Solo administrador. Usar un targetUserId de prueba; afecta acceso del usuario.', { active: false })
    ] }
  ]
};
await save('postman/RideMove.postman_collection.json', collection);
const variables = { baseUrl: 'http://127.0.0.1:8080', email: '', password: '', name: '', registrationRole: 'passenger', accessToken: '', refreshToken: '', userId: '', targetUserId: '', tripId: '', targetStatus: 'cancelled', origin: 'Universidad de Cundinamarca, Fusagasugá', destination: 'Plaza Mayor, Fusagasugá', phone: '', plate: '', brand: '', model: '', color: '', license: '' };
await save('postman/Local.postman_environment.json', { name: 'RideMove · Local (completar credenciales)', values: Object.entries(variables).map(([key, value]) => ({ key, value, enabled: true, type: ['password', 'accessToken', 'refreshToken'].includes(key) ? 'secret' : 'default' })), _postman_variable_scope: 'environment' });

const backlog = [
  ['RM-01','Estructurar el backend hexagonal','Backend',0,3,'','Dominio y aplicación no importan Spring ni adaptadores; ArchUnit pasa.','Implementado local'],
  ['RM-02','Persistencia PostgreSQL y RLS','Backend',0,5,'RM-01','Migraciones crean perfiles, vehículos y viajes; las RPC autorizan y protegen concurrencia.','Implementado local'],
  ['RM-03','Registro con Supabase Auth','Backend',1,3,'RM-01, RM-02','Validar correo, nombre y contraseña; solo passenger/driver; respetar confirmación por correo.','Implementado local'],
  ['RM-04','Login y renovación de sesión','Backend',1,3,'RM-03','Login devuelve tokens; refresh rota la sesión; logout revoca renovación; errores no exponen secretos.','Implementado local'],
  ['RM-05','Validar JWT en Spring Security','Backend',1,5,'RM-04','Rechazar JWT sin firma válida, expirado, con issuer o audience erróneos; usar sujeto verificado.','Implementado local'],
  ['RM-06','Endpoints para el Dashboard','Backend',1,3,'RM-02, RM-05','GET perfil y viajes usan actor autenticado; POST viaje aplica reglas de negocio y RLS.','Implementado local'],
  ['RM-07','Diseñar módulos de interfaz','Frontend',1,3,'RM-06','Entregar Login, Registro, Dashboard y pago demo como SVG editables y tokens.','Implementado local'],
  ['RM-08','Login Angular','Frontend',1,3,'RM-04, RM-07','Validar formulario, mostrar carga/error, autenticar por HTTP y guardar tokens en memoria.','Implementado local'],
  ['RM-09','Registro Angular','Frontend',1,3,'RM-03, RM-07','Formulario tipado; elegir pasajero/conductor; mostrar confirmación por email si no hay sesión.','Implementado local'],
  ['RM-10','Dashboard Angular','Frontend',1,5,'RM-06, RM-08','Mostrar perfil, métricas e historial reales; filtrar; mostrar estados vacío/error/carga.','Implementado local'],
  ['RM-11','Solicitud de viaje web','Frontend',1,3,'RM-10','Enviar origen/destino; impedir solicitud duplicada desde UI; reflejar resultado y errores del backend.','Implementado local'],
  ['RM-12','Pago visual de demostración','Frontend',1,2,'RM-10','Botón para viaje completado del pasajero; diálogo anuncia demo; no pide tarjetas ni cobra.','Implementado local'],
  ['RM-13','Entornos y tipado estricto','Ambos',1,2,'RM-08','No publicar .env; generar config pública; TypeScript strict y cero any explícitos.','Implementado local'],
  ['RM-14','Colección Postman y pruebas','Backend',1,3,'RM-05, RM-06','Entorno sin secretos; pruebas de códigos HTTP; peticiones de escritura identificadas.','Implementado local'],
  ['RM-15','Documentar SOLID y 12 factores','Ambos',1,2,'RM-13','Cada principio/factor tiene evidencia y se distingue de pendientes de infraestructura.','Implementado local'],
  ['RM-16','Crear ramas locales de promoción','Ambos',1,1,'RM-15','main, preproduccion y produccion parten de una base versionada sin secretos.','Implementado local'],
  ['RM-17','Prueba integral con cuentas de aceptación','Ambos',2,3,'RM-09, RM-11','En ambiente de prueba: registro, confirmar correo, login, crear viaje, operar desde Flutter y ver historial Angular.','Pendiente'],
  ['RM-18','Importar y organizar Jira y Figma','Frontend',2,2,'RM-07, RM-15','Importar CSV, asignar personas y sprints; importar SVG a Figma, añadir componentes y conexiones del prototipo.','Pendiente'],
  ['RM-19','Preparar remoto y CI/CD','Backend',2,5,'RM-16','Crear remoto del equipo, proteger ramas y ejecutar pruebas y compilación en cada revisión.','Pendiente'],
  ['RM-20','Desplegar preproducción y producción','Backend',2,5,'RM-17, RM-19','Configurar HTTPS, BD separadas, correo, CORS, logs y comprobaciones de salud; probar apagado y carga.','Pendiente'],
  ['RM-21','Implementar pagos reales','Ambos',3,8,'RM-12, RM-20','Definir tarifa, moneda y proveedor; orden backend, webhook firmado e idempotencia; pruebas sandbox antes de cobrar.','Pendiente'],
  ['RM-22','Extender operación web del conductor','Frontend',3,5,'RM-10, RM-17','Portar aceptación, navegación y finalización desde Flutter al módulo web si se aprueba esa ampliación.','Pendiente']
].map(([id,summary,owner,milestone,points,dependencies,acceptance,state]) => ({ id, summary, owner, milestone, points, dependencies, acceptance, state }));
await save('jira/backlog.json', backlog);
console.log('Postman y fuente del backlog generados sin credenciales.');
