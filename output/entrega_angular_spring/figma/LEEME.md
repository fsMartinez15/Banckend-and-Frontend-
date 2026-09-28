# Módulo de interfaz · RideMove

Estas pantallas son diseños vectoriales editables para importar en Figma. No
son un archivo `.fig` ni un proyecto publicado en una cuenta. Reflejan el módulo
Angular entregado, con ajustes de composición para presentar cada pantalla completa.

Importar los cinco SVG en un archivo de diseño y crear páginas «Fundamentos»,
«Autenticación», «Dashboard» y «Prototipo». Conservar los tamaños de los marcos.
Los colores y espaciados están en `tokens.json`; la aplicación usa Manrope y DM Sans.
Los SVG usan Arial para poder abrirlos sin instalar fuentes adicionales.

## Componentes sugeridos

Marca, botón primario/secundario, campo de texto, selector de rol, etiqueta de
estado, fila de viaje, tarjeta de métrica y diálogo de pago. Convertir grupos en
componentes nativos de Figma y configurar Auto Layout en la cuenta del equipo.
Los SVG contienen texto y formas; no contienen componentes, restricciones ni enlaces
interactivos propios de Figma.

## Conexiones del prototipo

Login → Crear cuenta → Registro. Registro aceptado → confirmar correo cuando
aplique → Login. Login válido → Dashboard. Dashboard → Pagar demo → diálogo.
Cerrar diálogo → Dashboard. Cerrar sesión → Login. Error de formulario mantiene
la pantalla y muestra mensaje. El botón demo usa datos de ejemplo y lo indica
de forma permanente en la cabecera.

El mapa del Dashboard web es una ilustración señalizada. La navegación con
mapa y trazado de ruta operativo permanece en la app Flutter. No confundir el
SVG de la tarjeta con un mapa navegable.

## Estados implementados

Formularios: vacío, inválido, enviando, error y sesión aceptada. Registro:
confirmación de correo. Dashboard: carga, error, vacío, resultados filtrados,
viaje activo, cuenta suspendida y perfiles conductor/administrador. Pago:
explicación de demo y confirmación visual sin transacción. Diseño adaptable y
diálogo HTML con foco modal, Escape y cierre con botón.
