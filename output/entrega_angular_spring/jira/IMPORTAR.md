# Backlog para Jira

`Backlog_Jira.csv` contiene 22 historias. `backlog.json` conserva la fuente del
plan. El libro de consulta está en `outputs/ridemove_entrega/Backlog.xlsx`.
Los puntos son estimaciones propuestas. Hito 0 = backend base; hito 1 = Login,
Registro y Dashboard; hito 2 = aceptación y publicación; hito 3 = ampliaciones.

En el importador CSV de Jira, seleccionar UTF-8 y separador coma. Mapear Summary
a Resumen, Description a Descripción, Issue Type a Tipo, Priority a Prioridad,
Labels a Etiquetas y Status a Estado. Adaptar Story, High/Medium e In Progress/To Do
a los valores disponibles en el proyecto. Si el importador de tu proyecto no
permite estados, importarlos como pendientes y actualizar después de revisar.

El estado «Implementado local» aparece en la descripción y se importa como
In Progress para revisión del equipo; no significa que ya exista aceptación
funcional en producción. Ninguna fila inventa un usuario Jira, sprint ni una
fecha de entrega. Asignar los nombres reales a los responsables sugeridos:
Backend, Frontend o Ambos. Crear los sprints después de estimar con el equipo.

Los identificadores RM-01…RM-22 son referencias locales incluidas en los títulos.
Jira asignará sus propias claves. Vincular las dependencias indicadas en cada
descripción después de importar. No volver a importar el CSV sin revisar posibles
duplicados.

Referencia del procedimiento: [Importación CSV de Atlassian](https://support.atlassian.com/jira-cloud-administration/docs/import-data-from-a-csv-file/).
