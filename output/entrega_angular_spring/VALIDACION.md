# Validación de la entrega

Fecha: 28/09/2026. Entorno local Windows, Java 21 y Node 24.13.

| Comprobación | Resultado |
|---|---|
| Maven `verify` | 35 pruebas aprobadas; JAR ejecutable generado |
| Arquitectura | 2 pruebas ArchUnit verifican límites del dominio y aplicación |
| JWT | 5 pruebas de firma, expiración, emisor y audiencia |
| Seguridad HTTP | 5 pruebas: salud pública, acceso protegido, rol falso y CORS permitido/rechazado |
| Angular | Build de producción correcto; carga inicial aproximada de 309 kB antes de compresión |
| Pruebas Angular | 8 aprobadas; incluyen refresh, aislamiento demo/real y POST viaje 201 sin cuerpo |
| Tipado | TypeScript y plantillas strict; comprobación AST sin `any` explícitos |
| Flutter conservado | `flutter analyze`: sin problemas |
| Backlog | 22 historias exportadas a CSV y XLSX; vista Excel renderizada y revisada |
| Interfaz | Login, Dashboard, navegación, pago demo y ancho móvil revisados en navegador; SVG editables entregados |

Las pruebas Java usan dobles de puertos y verificaciones criptográficas locales;
las Angular utilizan HttpTestingController. No equivalen a una prueba integral de
registro por correo y viaje con cuentas reales de aceptación. Ese recorrido queda
documentado en RM-17 y requiere cuentas de prueba del equipo. No se realizaron
cobros, publicaciones en Jira/Figma, despliegues públicos ni pruebas de carga.

La integración de base de datos usa las migraciones ya existentes de Supabase.
Los datos de «Explorar demostración» son temporales y están claramente señalizados.
