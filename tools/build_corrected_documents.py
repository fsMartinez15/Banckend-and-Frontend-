"""Reproducible corrected PDF sources; originals remain untouched."""
from pathlib import Path
from xml.etree import ElementTree as ET
from html import escape, unescape
import re
from reportlab.pdfgen import canvas
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, Flowable
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
import pypdfium2 as pdfium
from PIL import Image, ImageDraw

OUT=Path('output/documentos_corregidos'); OUT.mkdir(parents=True,exist_ok=True)
PREVIEW=Path('tmp/document-review'); PREVIEW.mkdir(parents=True,exist_ok=True)
pdfmetrics.registerFont(TTFont('Arial','C:/Windows/Fonts/arial.ttf'))
pdfmetrics.registerFont(TTFont('Arial-Bold','C:/Windows/Fonts/arialbd.ttf'))
pdfmetrics.registerFontFamily('Arial',normal='Arial',bold='Arial-Bold')
GREEN=colors.HexColor('#23785B'); INK=colors.HexColor('#142D27'); LIGHT=colors.HexColor('#EDF3E9')
styles=getSampleStyleSheet()
styles.add(ParagraphStyle(name='BodyRM',fontName='Arial',fontSize=10.5,leading=15,spaceAfter=10,textColor=INK))
styles.add(ParagraphStyle(name='HeadRM',fontName='Arial-Bold',fontSize=19,leading=24,spaceAfter=17,textColor=INK))
styles.add(ParagraphStyle(name='SubRM',fontName='Arial-Bold',fontSize=12,leading=17,spaceBefore=12,spaceAfter=8,textColor=GREEN))
styles.add(ParagraphStyle(name='CellRM',fontName='Arial',fontSize=9,leading=12,textColor=INK))
styles.add(ParagraphStyle(name='CoverRM',fontName='Arial-Bold',fontSize=30,leading=37,alignment=TA_CENTER,textColor=INK,spaceAfter=20))

def p(text,style='BodyRM'): return Paragraph(escape(text).replace('\n','<br/>'),styles[style])
def table(headers,rows,widths=None):
    data=[[p(x,'CellRM') for x in headers]]+[[p(str(x),'CellRM') for x in row] for row in rows]
    t=Table(data,colWidths=widths or [475/len(headers)]*len(headers),repeatRows=1,hAlign='LEFT')
    t.markdown='\n'.join([' | '.join(headers),' | '.join(['---']*len(headers))]+[' | '.join(map(str,row)) for row in rows])
    t.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),LIGHT),('LINEBELOW',(0,0),(-1,0),1,GREEN),('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),8),('RIGHTPADDING',(0,0),(-1,-1),8),('TOPPADDING',(0,0),(-1,-1),7),('BOTTOMPADDING',(0,0),(-1,-1),7),('LINEBELOW',(0,1),(-1,-1),.3,colors.HexColor('#D8E1D7'))]))
    return t

class Architecture(Flowable):
    def __init__(self): super().__init__(); self.width=475; self.height=250
    def draw(self):
        c=self.canv
        boxes=[(0,170,142,58,'Flutter','Adaptador móvil'),(166,170,145,58,'API REST','Adaptador de entrada'),(334,170,141,58,'Casos de uso','RideService'),(334,72,141,58,'Dominio','Entidades y reglas'),(166,72,145,58,'Puertos de salida','Interfaces Java'),(0,72,142,58,'SupabaseAdapter','HTTP y PostgreSQL')]
        for x,y,w,h,title,sub in boxes:
            c.setFillColor(LIGHT);c.setStrokeColor(GREEN);c.roundRect(x,y,w,h,7,fill=1)
            c.setFillColor(INK);c.setFont('Arial-Bold',11);c.drawCentredString(x+w/2,y+35,title);c.setFont('Arial',9);c.drawCentredString(x+w/2,y+17,sub)
        c.setStrokeColor(GREEN)
        for x1,y1,x2,y2 in [(142,199,166,199),(311,199,334,199),(404,170,404,130),(352,170,285,130),(142,100,166,100)]:
            c.line(x1,y1,x2,y2)
            if x2>x1: c.line(x2,y2,x2-5,y2+3);c.line(x2,y2,x2-5,y2-3)
            elif x2<x1:c.line(x2,y2,x2+5,y2+3);c.line(x2,y2,x2+5,y2-3)
            else:c.line(x2,y2,x2-3,y2+5);c.line(x2,y2,x2+3,y2+5)
        c.setFont('Arial',9);c.setFillColor(INK)
        c.drawString(0,43,'El adaptador implementa los puertos definidos por la aplicación.')
        c.drawString(0,27,'Dominio y casos de uso no importan Spring, Flutter ni Supabase.')

class Relations(Flowable):
    def __init__(self):super().__init__();self.width=475;self.height=170
    def draw(self):
        c=self.canv;c.setFont('Arial',11);c.setFillColor(INK)
        rows=[('auth.users','1 a 1','profiles'),('profiles','1 a 0..1','vehicles / locations'),('profiles','1 a N','trips como pasajero'),('profiles','1 a N','trips como conductor'),('trips + profiles','N a M','rejections')]
        for n,(a,b,d) in enumerate(rows):
            y=145-n*29;c.setFillColor(LIGHT);c.rect(0,y-8,475,26,fill=1,stroke=0);c.setFillColor(INK);c.drawString(10,y,a);c.drawString(170,y,b);c.drawString(265,y,d)

pages=[]
def page(title,body=None,table_data=None,extras=None):
    blocks=[p(title,'HeadRM')]
    for item in body or []:
        if isinstance(item,tuple): blocks.append(p(item[1],'SubRM' if item[0]=='h' else 'BodyRM'))
        else: blocks.append(p(item))
    if table_data:blocks.append(table(*table_data))
    if extras:blocks.extend(extras)
    pages.append((title,body or [],table_data,blocks))

tests=sum(int(ET.parse(x).getroot().attrib['tests']) for x in Path('backend/target/surefire-reports').glob('TEST-*.xml'))

page('RideMove',[
    'Documento consolidado del proyecto y arquitectura hexagonal',
    'Laura Camila Díaz Rey\nFabián Sneider Martínez Moreno',
    'Gestor del conocimiento\nLuis Ferney Ortiz Parra',
    'Universidad de Cundinamarca\nIngeniería de Sistemas y Computación\nIngeniería de Software I\n2026-2',
    'Versión 2.0\n22 de septiembre de 2026',
    'Este documento actualiza IS V1 y el primer comité de arquitectura. Conserva el problema, los actores y los requisitos funcionales de RideMove, y describe la implementación con Flutter, Java 21 y Supabase. La arquitectura hexagonal se aplica al backend mediante entidades, casos de uso, puertos y adaptadores comprobables en el código.'
])
page('Control de cambios y contenido',[
    'La versión inicial proponía React y Spring Boot sobre PostgreSQL. Por decisión del solicitante, Flutter reemplaza el frontend web y Supabase proporciona autenticación y PostgreSQL administrado. Java y Spring Boot se mantienen como backend para cumplir el lineamiento de arquitectura hexagonal y comunicación mediante HTTP.',
    'Esta revisión no modifica los PDF originales ni afirma aprobación del comité. La entrega describe los cambios técnicos realizados y conserva los objetivos académicos del proyecto.',
],(['Sección','Contenido'],[
 ['1 y 2','Introducción, problema, objetivos, actores y alcance'],['3','Enfoque iterativo incremental y Scrum'],['4','Requisitos funcionales, no funcionales y prioridades'],['5 y 6','Dependencias, tecnologías y arquitectura hexagonal'],['7','Riesgos y medidas de tratamiento'],['8','Modelo relacional y diccionario de datos'],['9','Conclusiones, validación y condiciones de ejecución'],['Anexos','Contrato HTTP, trazabilidad y referencias']],[65,410]))
page('1 Introducción del proyecto',[
 'En Fusagasugá, parte del transporte urbano y semiurbano se coordina mediante grupos de WhatsApp y llamadas. Las solicitudes pueden perderse entre mensajes y dependen de que un conductor responda oportunamente. El pasajero tiene poca claridad sobre el estado del servicio y los participantes no cuentan con un historial centralizado.',
 'RideMove organiza ese proceso mediante una aplicación móvil. El pasajero registra origen y destino, los conductores disponibles consultan las solicitudes y uno acepta el servicio. La plataforma registra los cambios de estado y permite calificar el viaje al finalizar.',
 'La solución se divide en aplicación móvil, backend de negocio y servicios de datos. Flutter presenta las pantallas y administra la interacción con el GPS. La API Java ejecuta los casos de uso. Supabase administra las identidades, los datos persistentes y las restricciones transaccionales.',
 ('h','Objetivo general'),
 'Desarrollar una primera versión funcional de RideMove que permita solicitar, atender, seguir y calificar servicios de transporte en Fusagasugá, con control por roles y un backend cuya lógica sea independiente de los frameworks y de la persistencia.',
 ('h','Objetivos específicos'),
 'Registrar solicitudes con origen y destino. Permitir al conductor gestionar su disponibilidad y atender solicitudes. Consultar el estado y la ubicación compartida durante el servicio. Conservar historial y calificaciones. Dar al administrador herramientas básicas de supervisión y gestión de usuarios y vehículos.'
])
page('2 Descripción general del sistema',[
 ('h','Problema y flujo de servicio'),
 'La coordinación manual dispersa la información y obliga a confirmar el servicio por varios canales. RideMove centraliza el flujo: solicitud pendiente, aceptación por un conductor, inicio del viaje, finalización y calificación. El pasajero puede cancelar mientras la solicitud siga pendiente.',
 ('h','Usuarios del sistema'),
],(['Actor','Necesidad y capacidades'],[
 ['Pasajero','Registrar y editar su perfil. Solicitar o cancelar un servicio pendiente. Consultar estado, conductor asignado, vehículo y mapa. Calificar su viaje finalizado.'],
 ['Conductor','Registrar perfil, licencia y vehículo. Activar disponibilidad. Consultar, aceptar o rechazar solicitudes. Iniciar y finalizar el viaje. Compartir ubicación durante un servicio activo.'],
 ['Administrador','Consultar usuarios, conductores, vehículos y servicios. Suspender o reactivar usuarios cuando no tienen servicios activos. Corregir información de vehículos. Revisar conteos generales.']],[100,375]),extras=[Spacer(1,16),p('Alcance de la primera versión','SubRM'),p('Incluye autenticación, perfil, servicios, historial, calificaciones, mapa del conductor y gestión básica. Se registra un vehículo actual por conductor y la última ubicación enviada. No incluye pagos electrónicos, integración bancaria, tarifas automáticas complejas ni asignación por inteligencia artificial.'),p('La ubicación se actualiza en primer plano al desplazarse el conductor, con consentimiento explícito. Se detiene al salir de la app o finalizar el viaje. El seguimiento en segundo plano no forma parte de esta entrega.')])
page('3 Enfoque metodológico',[
 ('h','Enfoque iterativo incremental'),
 'Los requisitos del flujo principal son estables, pero la interfaz, la gestión administrativa y los detalles de ubicación requieren validación con los usuarios y el docente. El proyecto se organiza mediante entregas pequeñas que permiten revisar las reglas y corregir decisiones técnicas sin reconstruir todo el sistema.',
 ('h','Scrum como marco de trabajo'),
 'El equipo está conformado por Laura Camila Díaz Rey y Fabián Sneider Martínez Moreno. Se propone trabajar con sprints de una a dos semanas. La planificación selecciona requisitos del backlog, el seguimiento diario revisa impedimentos, la revisión demuestra un incremento y la retrospectiva identifica mejoras. Estas actividades son el plan metodológico y no constituyen un registro de ceremonias ya realizadas.',
 ('h','Backlog por valor funcional'),
],(['Incremento','Objetivo','Criterio de revisión'],[
 ['Usuarios','Registro, sesión y perfil','Cada rol accede a las funciones permitidas.'],['Servicios','Solicitud y atención del viaje','Un servicio recorre los estados válidos y conserva historial.'],['Seguimiento','GPS y mapa','El pasajero asignado consulta la ubicación del viaje activo.'],['Calidad y administración','Calificaciones, gestión y pruebas','Las reglas se prueban sin depender de Supabase y se verifican en PostgreSQL.']],[90,170,215]))

rf=[
 ['RF-01','Gestión de perfil','Pasajero y conductor consultan y actualizan nombre y teléfono.','Media'],
 ['RF-02','Solicitud de servicio','El pasajero informa lugares diferentes de origen y destino y crea un viaje pendiente.','Alta'],
 ['RF-03','Disponibilidad','El conductor activa o desactiva su disponibilidad. Para activarla necesita un vehículo registrado.','Alta'],
 ['RF-04','Consulta de solicitudes','El conductor consulta solicitudes pendientes que no ha rechazado.','Alta'],
 ['RF-05','Aceptación o rechazo','Un conductor disponible acepta una solicitud. El rechazo la oculta para ese conductor y permite que otros la atiendan.','Alta'],
 ['RF-06','Actualización del estado','El conductor asignado inicia el viaje aceptado y finaliza el viaje en curso.','Alta'],
 ['RF-07','Consulta y seguimiento','El pasajero ve estado, nombre del conductor, vehículo y última ubicación compartida durante el viaje activo.','Alta'],
 ['RF-08','Calificación','Solo el pasajero propietario califica una vez un servicio finalizado, de 1 a 5, con comentario opcional.','Media'],
 ['RF-09','Gestión administrativa','El administrador consulta servicios y usuarios, cambia su acceso y edita vehículos de conductores.','Media'],
]
page('4 Requisitos funcionales',[
 'Se conserva la codificación del documento inicial. La cancelación de una solicitud pendiente complementa RF-02 y la visualización del mapa concreta el seguimiento de RF-07.'
],(['Código','Requisito','Criterio funcional','Prioridad'],rf,[47,106,259,63]))
page('4 Requisitos no funcionales',[
 'Los criterios siguientes distinguen lo implementado de los objetivos que requieren mediciones adicionales. Una prueba unitaria no demuestra por sí sola el rendimiento de la plataforma en producción.'
],(['Categoría','Criterio de aceptación','Evidencia o límite'],[
 ['Seguridad de credenciales','Delegar las contraseñas a Supabase Auth y no almacenarlas en perfiles ni en la app.','La app usa clave pública y tokens de sesión. El backend no necesita la contraseña de PostgreSQL para operar.'],
 ['Control de acceso','Validar identidad, rol, propiedad del servicio y estado de la cuenta.','Validación de token por Auth, reglas Java y RLS en PostgreSQL. Pruebas de acceso no autorizado.'],
 ['Rendimiento','Responder las operaciones principales en un máximo de 3 segundos bajo condiciones normales.','Objetivo conservado. Pendiente medición con usuarios y red reales. El refresco de pantalla se realiza cada 10 segundos.'],
 ['Escalabilidad','Permitir crecimiento manteniendo consistencia de asignación.','Índices y restricciones únicas. La API actual conserva el límite de lectura de PostgREST; paginación e indicadores masivos requieren ampliación.'],
 ['Mantenibilidad','El núcleo no depende de Spring, HTTP, Flutter ni Supabase.','Pruebas ArchUnit verifican las dependencias del dominio y los casos de uso.'],
 ['Usabilidad','Solicitar un servicio en no más de tres pasos.','Escribir origen, escribir destino y pulsar Solicitar. Prueba de interfaz de 390 píxeles de ancho.']],[87,185,203]))
page('5 Dependencias del proyecto',[
 'La infraestructura externa se utiliza mediante adaptadores y configuración. La disponibilidad de internet condiciona la autenticación, la consulta de servicios, los mapas y la sincronización de ubicación.'
],(['Dependencia','Uso e impacto'],[
 ['Flutter y Dart','Aplicación móvil y acceso al GPS. Impacto alto para el cliente.'],['Java 21 y Spring Boot 3.5.16','API HTTP, configuración y ejecución del backend. Impacto alto. La versión indicada corresponde al artefacto compilado.'],['Supabase Auth','Registro, confirmación de correo, inicio y renovación de sesión. Impacto alto.'],['PostgreSQL administrado por Supabase','Datos, transacciones, restricciones y RLS. Impacto alto. No se presupone una versión mayor sin consultar el proyecto.'],['PostgREST y funciones RPC','Adaptador HTTP de persistencia que conserva el token del usuario. Impacto alto.'],['flutter_map y OpenStreetMap','Mapa con atribución visible. Impacto medio. Los mosaicos requieren internet.'],['Maven y Flutter SDK','Compilación, análisis y pruebas reproducibles. Java 21 disponible en el equipo de trabajo.'],['Git y repositorio remoto','Control de versiones previsto. La carpeta suministrada no tenía un repositorio Git inicializado; no se afirma publicación remota.']],[148,327]))
page('6 Arquitectura hexagonal',[
 'El núcleo de negocio reside en backend/src/main/java/co/ridemove. Las entidades Profile, Trip, Vehicle y DriverLocation definen información y reglas. RideService implementa el puerto de entrada RideUseCases y depende únicamente de puertos de salida.',
 'El controlador REST traduce las solicitudes HTTP a llamadas de casos de uso. SupabaseAdapter implementa ProfilePort, TripPort, VehiclePort y LocationPort. La configuración conecta estas piezas e identifica al usuario autenticado. El núcleo puede probarse con sustitutos en memoria o Mockito sin arrancar Spring ni acceder a la base de datos.'
],extras=[Architecture(),p('Dirección de las dependencias','SubRM'),p('El dominio depende de Java estándar. La aplicación depende del dominio y de sus interfaces. Los adaptadores dependen de esas interfaces. La configuración conoce las implementaciones concretas para construir el sistema. Flutter funciona como cliente de la API REST y Supabase Auth conserva la gestión de identidad.'),p('Las funciones SQL repiten las reglas sensibles al estado concurrente. Son una garantía de integridad en la persistencia; los casos de uso Java validan previamente las reglas del negocio.')])
page('6 Reglas y estados del servicio',[
 'Las operaciones verifican el rol y la propiedad antes de escribir. La base de datos repite la comprobación dentro de la transacción para cubrir cambios ocurridos después de la lectura del backend.'
],(['Estado inicial','Acción y actor','Estado final'],[
 ['Pendiente','Conductor disponible acepta','Aceptado'],['Pendiente','Pasajero propietario cancela','Cancelado'],['Aceptado','Conductor asignado inicia','En curso'],['En curso','Conductor asignado finaliza','Finalizado'],['Finalizado','Pasajero propietario califica','Finalizado con calificación']],[100,270,105]),extras=[Spacer(1,18),p('Consistencia y concurrencia','SubRM'),p('Un índice parcial impide más de un viaje activo por pasajero. Otro impide dos viajes aceptados o en curso por conductor. La función transition_trip bloquea la fila del viaje antes de asignarlo y verifica su estado. Dos conductores no pueden aceptar con éxito la misma solicitud.'),p('El rechazo se registra por solicitud y conductor. No cambia el estado global del viaje. La calificación acepta enteros de 1 a 5, exige viaje finalizado y rechaza una segunda calificación.'),p('La ubicación solo puede enviarse durante un viaje aceptado o en curso. RLS permite verla al conductor, al pasajero asignado y al administrador. El pasajero pierde acceso al finalizar el servicio.')])
page('7 Riesgos del proyecto',[],(['Riesgo','Nivel','Tratamiento y validación pendiente'],[
 ['Errores de GPS o permisos denegados','Medio','Solicitar permiso, informar el fallo y permitir detener el envío. Validar precisión y consumo en un teléfono físico.'],['Exposición de datos o escalamiento de roles','Alto','Auth valida tokens, el rol se lee de profiles y RLS limita filas. El registro público no permite crear administradores.'],['Asignación concurrente','Alto','Bloqueo transaccional y restricciones únicas. Las pruebas actuales verifican flujo y duplicados; queda pendiente una prueba de carga concurrente.'],['Dependencia de internet y servicios externos','Alto','Tiempos de espera finitos, mensajes de error y actualización manual. No se ofrece operación de transporte sin conexión.'],['Complejidad técnica y tiempo del equipo','Alto','Separar responsabilidades, conservar pruebas de arquitectura y priorizar RF-02 a RF-07.'],['Cambios del comité','Medio','Revisión por incremento y actualización de la matriz de requisitos. La aprobación académica corresponde al comité.'],['Disponibilidad pública del backend','Alto','Entregar ejecutable y Dockerfile. El backend local necesita alojamiento HTTPS para que el APK funcione fuera de la red de desarrollo.']],[155,42,278]))
page('8 Modelo de base de datos',[
 'La implementación utiliza cinco tablas públicas y auth.users, administrada por Supabase Auth. Los identificadores de usuario son UUID. Los nombres físicos se conservan en inglés para coincidir con las migraciones y el adaptador; los nombres de las entidades del informe inicial se mapean explícitamente a continuación.'
],extras=[Relations(),table(['Entidad del informe inicial','Implementación física y decisión'],[
 ['USUARIO','auth.users administra identidad y contraseña; profiles conserva nombre, teléfono, rol y acceso.'],['CONDUCTOR','Especialización mediante profiles.role y profiles.available; la licencia está en vehicles.'],['VEHICULO','vehicles conserva el vehículo actual de cada conductor. Un conductor tiene como máximo un registro vigente.'],['UBICACION','locations conserva la última coordenada y fecha. No constituye un historial de recorridos.'],['SOLICITUD','trips relaciona pasajero y conductor, con estados y fechas.'],['CALIFICACION','rating y comment en trips. Una calificación por viaje.'],['RECHAZO','rejections registra la relación solicitud-conductor rechazada.']],[150,325])])

page('8 Diccionario de datos de usuarios y vehículos',[],(['Tabla y campo','Tipo','Restricción y significado'],[
 ['profiles.id','uuid','PK y FK a auth.users.id. Eliminación en cascada desde identidad.'],['profiles.name','text','Obligatorio, de 2 a 80 caracteres. Nombre del usuario.'],['profiles.phone','text','Hasta 25 caracteres. Teléfono de contacto; puede estar vacío.'],['profiles.role','text','passenger, driver o admin. El registro solo acepta passenger o driver.'],['profiles.active','boolean','Control del acceso a la plataforma. Valor inicial true.'],['profiles.available','boolean','Disponibilidad del conductor. Valor inicial false.'],['vehicles.driver_id','uuid','PK y FK a profiles.id. Identifica al propietario y limita a un vehículo actual.'],['vehicles.plate','text','Placa única, de 3 a 10 caracteres. Se normaliza a mayúsculas.'],['vehicles.brand','text','Marca de 1 a 40 caracteres.'],['vehicles.model','text','Modelo o año de 1 a 20 caracteres.'],['vehicles.color','text','Color de 1 a 30 caracteres.'],['vehicles.license','text','Licencia de conducción de 1 a 40 caracteres.']],[153,60,262]))
page('8 Diccionario de datos de viajes',[],(['Campo de trips','Tipo','Restricción y significado'],[
 ['id','uuid','PK generada por PostgreSQL.'],['passenger_id','uuid','FK a profiles.id. Pasajero que solicitó el servicio.'],['driver_id','uuid o null','FK a profiles.id. Se asigna al aceptar.'],['origin','text','Lugar de recogida, de 3 a 150 caracteres.'],['destination','text','Destino de 3 a 150 caracteres, diferente del origen.'],['status','text','pending, accepted, in_progress, completed o cancelled.'],['created_at','timestamptz','Fecha de solicitud; valor inicial now().'],['completed_at','timestamptz o null','Fecha obligatoria solo cuando el estado es completed.'],['rating','integer o null','Valor de 1 a 5. Solo para un servicio finalizado.'],['comment','text o null','Comentario opcional de hasta 255 caracteres.']],[153,85,237]),extras=[Spacer(1,18),p('Integridad del viaje','SubRM'),p('Las claves foráneas conservan la relación con las personas. Los índices one_active_passenger_trip y one_active_driver_trip impiden servicios activos incompatibles. El estado y la fecha de finalización deben ser consistentes. Las transiciones y la autoría de la calificación se controlan mediante RPC.')])
page('8 Diccionario de ubicación y rechazo',[],(['Tabla y campo','Tipo','Restricción y significado'],[
 ['locations.driver_id','uuid','PK y FK a profiles.id. Un último punto por conductor.'],['locations.latitude','double precision','Latitud entre -90 y 90.'],['locations.longitude','double precision','Longitud entre -180 y 180.'],['locations.updated_at','timestamptz','Fecha de la última actualización.'],['rejections.trip_id','uuid','FK a trips.id. Parte de la PK compuesta.'],['rejections.driver_id','uuid','FK a profiles.id. Parte de la PK compuesta.']],[153,100,222]),extras=[Spacer(1,18),p('Políticas de acceso','SubRM'),p('Todas las tablas públicas tienen RLS. Los clientes autenticados reciben SELECT y acceso a funciones específicas, sin INSERT, UPDATE ni DELETE directos. Los pasajeros consultan sus viajes; los conductores consultan los asignados y las solicitudes pendientes no rechazadas. Administración tiene visibilidad general.'),p('auth.users es propiedad de Supabase Auth. La contraseña no se replica en profiles ni se almacena como texto en la app. No se incluyen credenciales privadas en este documento.'),p('Migraciones','SubRM'),p('202609180001_initial.sql crea el esquema inicial. 202609220001_hexagonal_support.sql añade la edición administrativa de vehículos y refuerza calificaciones, ubicación y coherencia temporal. La segunda migración se aplica una sola vez después de la primera.')])

routes=[['GET','/api/profile','Perfil propio'],['GET','/api/profiles','Usuarios visibles por rol'],['GET','/api/trips','Solicitudes e historial visibles'],['GET','/api/vehicles','Vehículos visibles'],['GET','/api/locations','Últimas posiciones autorizadas'],['POST','/api/trips','Crear solicitud'],['PUT','/api/trips/{id}/status','Aceptar, cancelar, iniciar o finalizar'],['POST','/api/trips/{id}/rejections','Rechazar para el conductor actual'],['POST','/api/trips/{id}/rating','Calificar el servicio'],['PUT','/api/profile','Actualizar perfil'],['PUT','/api/availability','Cambiar disponibilidad'],['PUT','/api/profiles/{id}/access','Administrar acceso'],['PUT','/api/vehicle','Guardar vehículo propio o administrado'],['PUT','/api/location','Enviar posición durante servicio activo']]
page('Anexo A Contrato HTTP',[
 'Las operaciones de negocio requieren Authorization: Bearer con un token de Supabase Auth. El backend verifica el token con Auth y utiliza el identificador validado. No acepta roles enviados por la aplicación como autorización. GET /health es público y solo indica que el proceso está activo.'
],(['Método','Ruta','Propósito'],routes,[52,225,198]),extras=[Spacer(1,12),p('Respuestas: 200 para operaciones exitosas, 201 para crear solicitud, 400 para datos mal formados, 401/403 para acceso no autorizado, 409 para reglas de negocio o conflicto de estado, y 503 cuando la dependencia externa no responde.')])
page('Anexo B Trazabilidad de requisitos',[],(['Requisito','Caso de uso en RideService','Evidencia de implementación'],[
 ['RF-01','profile y saveProfile','Perfil Flutter, puerto ProfilePort y RPC save_profile.'],['RF-02','createTrip','Formulario Flutter, validación del destino y prueba de duplicados.'],['RF-03','setAvailability','Interruptor Flutter, requisito de vehículo y RPC atómica.'],['RF-04','trips','Lectura filtrada por RLS y exclusión de rechazos.'],['RF-05','transitionTrip y rejectTrip','Reglas de rol, vehículo, disponibilidad y bloqueo en PostgreSQL.'],['RF-06','transitionTrip','Trip.validateTransition y pruebas de secuencia de estados.'],['RF-07','trips y locations','Mapa OpenStreetMap, LocationTracker y puerto LocationDevice.'],['RF-08','rateTrip','Trip.validateRating, validación de rango y prueba de autoría.'],['RF-09','profiles, setActive y saveVehicle','Panel administrativo, restricciones sobre viajes activos y edición de vehículos.']],[52,165,258]),extras=[Spacer(1,16),p('Pruebas y evidencia','SubRM'),p(f'La suite Java contiene {tests} pruebas que verifican reglas, arquitectura, HTTP y el adaptador de persistencia. Las pruebas Flutter cubren la interfaz móvil, el flujo de demostración, los duplicados y la parada del GPS. El script supabase/tests/workflow.sql verifica un flujo real y el aislamiento RLS dentro de una transacción que revierte sus datos de prueba.')])
page('9 Conclusiones y condiciones de ejecución',[
 'RideMove conserva el alcance funcional principal definido en IS V1. La incorporación del backend Java convierte la separación de capas inicial en una arquitectura hexagonal verificable: los casos de uso utilizan interfaces y las tecnologías externas quedan en adaptadores. Flutter mantiene el cliente móvil solicitado y Supabase conserva la autenticación y PostgreSQL.',
 'Las comprobaciones realizadas permiten revisar reglas de negocio, estructura de dependencias, aislamiento de datos y compilación. No equivalen a una certificación de rendimiento, seguridad integral o usabilidad con usuarios reales.',
 ('h','Ejecución y despliegue'),
 'El backend requiere Java 21 y las variables SUPABASE_URL y SUPABASE_ANON_KEY. tools/start_backend.ps1 inicia el JAR usando el archivo local de configuración. La app requiere API_BASE_URL. Para el emulador Android la dirección del equipo anfitrión es http://10.0.2.2:8080; un teléfono físico necesita una dirección de red accesible o una API HTTPS alojada.',
 'La entrega incorpora Dockerfile y ejecutable Java. No se afirma despliegue público del backend. La versión iOS requiere compilación y firma desde macOS. El APK de depuración permite pruebas; una distribución pública necesita firma de publicación y configuración HTTPS.',
 ('h','Validaciones pendientes'),
 'Medición del objetivo de tres segundos con red y usuarios reales. Prueba de carga y concurrencia. Validación del GPS, permisos y batería en un dispositivo físico. Revisión académica de los cambios tecnológicos. Paginación de grandes historiales y revisión de operación pública del servicio.',
 ('h','Referencias'),
 'Fuentes del proyecto: IS V1.pdf, páginas 3 a 23, y Comité.pdf, páginas 1 a 9. Código, migraciones y pruebas del repositorio RideMove, revisión del 22 de septiembre de 2026.',
 'Documentación técnica: docs.spring.io/spring-boot/3.5/system-requirements.html; supabase.com/docs; docs.fleaflet.dev; openstreetmap.org/copyright.'
])

def footer(c,doc):
    c.saveState();c.setFont('Arial',8);c.setFillColor(colors.HexColor('#60756B'))
    c.drawString(60,30,'RideMove  /  Ingeniería de Software I  /  Versión 2.0')
    c.drawRightString(535,30,str(doc.page));c.restoreState()

story=[]
for i,(_,_,_,blocks) in enumerate(pages):
    if i:story.append(PageBreak())
    if i==0:
        story.extend([Spacer(1,58),p('RideMove','CoverRM')])
        for text in pages[0][1][:-1]:
            center_style=ParagraphStyle('center',parent=styles['BodyRM'],alignment=TA_CENTER,spaceAfter=22)
            story.append(Paragraph(escape(text).replace('\n','<br/>'),center_style))
        story.extend([Spacer(1,15),p(pages[0][1][-1])])
    else:story.extend(blocks)
SimpleDocTemplate(str(OUT/'IS_V2_corregido.pdf'),pagesize=(595.28,841.89),leftMargin=60,rightMargin=60,topMargin=55,bottomMargin=55,title='RideMove Documento consolidado y arquitectura hexagonal',author='Laura Camila Díaz Rey y Fabián Sneider Martínez Moreno').build(story,onFirstPage=footer,onLaterPages=footer)

markdown=[]
for _,_,_,blocks in pages:
    for block in blocks:
        if isinstance(block,Paragraph):
            prefix='# ' if block.style.name=='HeadRM' else '## ' if block.style.name=='SubRM' else ''
            markdown.append(prefix+unescape(re.sub('<[^>]+>','',block.text.replace('<br/>','\n')))+'\n')
        elif isinstance(block,Table):markdown.append(block.markdown+'\n')
        elif isinstance(block,Architecture):markdown.append('```mermaid\nflowchart LR\n Flutter --> REST\n REST --> CasosDeUso\n CasosDeUso --> Dominio\n CasosDeUso --> Puertos\n SupabaseAdapter -. implementa .-> Puertos\n```\n')
        elif isinstance(block,Relations):markdown.append('auth.users 1 a 1 profiles\nprofiles 1 a 0..1 vehicles y locations\nprofiles 1 a N trips como pasajero y conductor\ntrips y profiles N a M mediante rejections\n')
(OUT/'IS_V2_fuente.md').write_text('\n'.join(markdown),encoding='utf-8')

slides=[
 ('RideMove','Primer comité de arquitectura actualizado',[
  ('Proyecto','Solicitud y gestión de transporte en Fusagasugá'),
  ('Equipo','Laura Camila Díaz Rey\nFabián Sneider Martínez Moreno'),
  ('Programa','Ingeniería de Software I\nUniversidad de Cundinamarca\n22 de septiembre de 2026')]),
 ('Contexto del proyecto','Movilidad urbana y semiurbana',[
  ('Situación actual','Las solicitudes dependen de mensajes de WhatsApp y llamadas para confirmar el servicio.'),
  ('Necesidad','Un canal que reúna la solicitud, el conductor asignado, el estado del viaje y su historial.'),
  ('Alcance','Aplicación móvil para pasajeros, conductores y administración.')]),
 ('Problema y solución','Un flujo de servicio trazable',[
  ('Solicitud','El pasajero registra origen y destino. La plataforma crea un servicio pendiente.'),
  ('Atención','Un conductor disponible acepta. Solo el asignado puede iniciar y finalizar el viaje.'),
  ('Cierre','El pasajero consulta su historial y califica el viaje finalizado una sola vez.')]),
 ('Usuarios del sistema','Acceso según el rol',[
  ('Pasajero','Solicita transporte, consulta el estado y el mapa del conductor, y califica el servicio.'),
  ('Conductor','Gestiona disponibilidad y vehículo. Acepta o rechaza solicitudes y comparte ubicación durante el viaje.'),
  ('Administrador','Consulta servicios y usuarios. Suspende o reactiva acceso y corrige vehículos de conductores.')]),
 ('Arquitectura hexagonal','El núcleo define las reglas del negocio',[
  ('Entrada','Flutter envía HTTP a la API REST de Spring Boot. El controlador llama a RideUseCases.'),
  ('Núcleo','RideService y las entidades Java validan roles, estados, autoría y disponibilidad. No importan frameworks.'),
  ('Salida','SupabaseAdapter implementa los puertos de perfiles, viajes, vehículos y ubicación. PostgreSQL conserva la integridad.')]),
 ('Modelo de datos y seguridad','Información persistente y acceso controlado',[
  ('Identidad y perfiles','Supabase Auth administra credenciales. profiles conserva rol, teléfono, disponibilidad y acceso.'),
  ('Servicio','trips guarda estados, fechas y calificación. vehicles y locations guardan vehículo actual y última ubicación. rejections registra rechazos.'),
  ('Protección','RLS filtra registros. Las RPC bloquean asignaciones incompatibles. El backend verifica el token y el rol real.')]),
 ('Tecnologías seleccionadas','Configuración implementada',[
  ('Aplicación móvil','Flutter y Dart. geolocator para GPS. flutter_map y OpenStreetMap para visualizar al conductor.'),
  ('Backend','Java 21 y Spring Boot 3.5.16. API REST con núcleo hexagonal y puertos independientes.'),
  ('Datos y pruebas','Supabase Auth y PostgreSQL. Maven, JUnit, Mockito, ArchUnit y flutter_test.')]),
 ('Metodología y validación','Incrementos revisables con Scrum',[
  ('Plan de trabajo','Sprints de una a dos semanas: usuarios, servicios, seguimiento y administración. Revisión del incremento con el comité.'),
  ('Pruebas ejecutadas',f'{tests} pruebas Java del núcleo, arquitectura, HTTP y persistencia. Pruebas Flutter de interfaz, flujo y seguimiento.'),
  ('Integración de datos','Flujo comprobado en Supabase con aislamiento RLS. Los registros de prueba se revirtieron al finalizar.')]),
 ('Alcance de esta entrega','Condiciones para la siguiente revisión',[
  ('Implementado','RF-01 a RF-09, API hexagonal, mapa del conductor, ubicación en primer plano, esquema y pruebas.'),
  ('Fuera del alcance inicial','Pagos electrónicos, bancos, tarifas complejas y asignación mediante inteligencia artificial.'),
  ('Validación pendiente','Alojar la API con HTTPS, probar GPS en teléfono físico y medir rendimiento y concurrencia con usuarios reales.')]),
]
c=canvas.Canvas(str(OUT/'Comite_V2_corregido.pdf'),pagesize=(960,540));c.setTitle('RideMove Comité de arquitectura actualizado');c.setAuthor('Laura Camila Díaz Rey y Fabián Sneider Martínez Moreno')
for n,(title,subtitle,items) in enumerate(slides):
    c.setFillColor(colors.HexColor('#F7F8F2'));c.rect(0,0,960,540,fill=1,stroke=0)
    c.setFillColor(INK);c.rect(0,0,28,540,fill=1,stroke=0)
    c.setFillColor(GREEN);c.setFont('Arial-Bold',12);c.drawString(62,497,'RIDEMOVE / COMITÉ DE ARQUITECTURA')
    c.setFillColor(INK);c.setFont('Arial-Bold',31);c.drawString(62,449,title)
    c.setFont('Arial',16);c.setFillColor(GREEN);c.drawString(62,414,subtitle)
    for i,(label,body) in enumerate(items):
        y=342-i*104
        c.setFillColor(GREEN);c.setFont('Arial-Bold',17);c.drawString(62,y,label)
        para=Paragraph(escape(body).replace('\n','<br/>'),ParagraphStyle('slide',fontName='Arial',fontSize=17,leading=24,textColor=INK))
        w,h=para.wrap(605,92)
        if h>92:raise ValueError(f'Slide overflow {n+1}: {label}')
        para.drawOn(c,305,y+16-h)
    c.setFillColor(GREEN);c.setFont('Arial',10);c.drawString(62,28,'Flutter + Java 21 + Supabase  /  Versión 2.0  /  22 septiembre 2026');c.drawRightString(912,28,f'{n+1:02d} / 09')
    c.showPage()
c.save()
(OUT/'Comite_V2_fuente.md').write_text('\n\n'.join('# '+t+'\n'+s+'\n\n'+'\n\n'.join('## '+a+'\n'+b for a,b in items) for t,s,items in slides),encoding='utf-8')

for file in OUT.glob('*.pdf'):
    doc=pdfium.PdfDocument(file);print(file.name,len(doc),'páginas')
    thumbs=[]
    for i,page in enumerate(doc):
        image=page.render(scale=1.25).to_pil().convert('RGB');image.save(PREVIEW/f'{file.stem}-{i+1:02}.png')
        image.thumbnail((350,450));tile=Image.new('RGB',(370,480),'#dddddd');tile.paste(image,((370-image.width)//2,10));ImageDraw.Draw(tile).text((10,460),str(i+1),fill='black');thumbs.append(tile)
    for start in range(0,len(thumbs),9):
        batch=thumbs[start:start+9];sheet=Image.new('RGB',(1110,480*((len(batch)+2)//3)),'white')
        for n,tile in enumerate(batch):sheet.paste(tile,((n%3)*370,(n//3)*480))
        sheet.save(PREVIEW/f'{file.stem}-contact-{start//9}.png')
