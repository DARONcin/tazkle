# Navegación y estructura de interfaz

## Navegación principal

- Resumen.
- Mapa del proyecto.
- Arquitectura.
- Equipo.
- Factibilidad.
- Costos.
- Plan de trabajo.
- Perfil y configuración.

El catálogo de bloques aparece únicamente en Mapa del proyecto y Arquitectura. Las demás áreas usan filtros, resúmenes e inspectores apropiados para reducir saturación.
Perfil y configuración no compite con las áreas del proyecto: se presenta como
la tarjeta fija de la persona en el extremo inferior de la sidebar.

## Proyectos y creación

- El encabezado de la sidebar muestra únicamente la firma completa de Tazkle:
  símbolo y wordmark aprobados.
- El proyecto actual aparece como selector global en la barra nativa de la
  ventana, ocupando el espacio antes usado para reiterar el apartado ya
  seleccionado en la sidebar. Su menú permite cambiar entre proyectos locales
  sin mezclar bloques, relaciones, selección ni estado del inspector.
- `Nuevo proyecto…` está disponible en ese selector y mediante `⌘N`.
- Crear un proyecto ocurre antes de entrar al espacio de trabajo: primero se
  define el nombre, después se elige la plantilla, se configura su stack y
  finalmente se revisa una confirmación explícita.
- La primera versión ofrece `Aplicación web` y `Lienzo vacío`. Aplicación móvil
  y software empresarial aparecen como próximas plantillas, sin simular que ya
  pueden utilizarse.
- La plantilla de aplicación web permite seleccionar frontend, lenguaje backend,
  estilo de API, autenticación, base de datos e infraestructura. Crea seis
  bloques conectados mediante siete relaciones tipadas en las cuatro capas de
  arquitectura. El lienzo vacío no crea estructura. En ambos casos la
  evaluación de factibilidad permanece pendiente.
- Las combinaciones discutibles permanecen permitidas con una advertencia
  explícita; la relación afectada y el bloque técnico se crean con atención
  requerida para que el equipo documente la excepción.
- Cada creación y cambio de proyecto se guarda localmente y restablece la vista
  en Resumen. Ningún dato se envía a un servicio externo.

Entre la firma de Tazkle y el perfil fijo, la sidebar se reparte en dos zonas de
igual altura:

- La mitad superior contiene los apartados principales del proyecto.
- La mitad inferior contiene las subvistas del apartado seleccionado.
- En Mapa del proyecto y Arquitectura, la zona inferior se convierte en la
  biblioteca de bloques correspondiente.
- Cambiar de apartado restablece su subvista inicial; cambiar de subvista
  conserva el apartado y evita duplicar información del proyecto.

## Patrón macOS

```text
Sidebar de navegación | Contenido principal | Inspector contextual
```

- La sidebar se puede ocultar.
- El inspector aparece solo cuando existe una selección o tarea que lo requiere.
- El inspector se puede contraer desde su encabezado, la toolbar o `⌥⌘I`
  sin perder la selección. Al cerrarlo, el lienzo recupera automáticamente
  todo el ancho disponible.
- Seleccionar un bloque abre su inspector contextual; pulsar el fondo del lienzo
  limpia la selección y recupera todo el ancho del área de trabajo.
- La barra del lienzo ocupa una sola fila compacta: concentra proyección,
  herramienta, estado y acciones sin competir con el diagrama.
- Factibilidad, costos y plan de trabajo priorizan resumen antes que detalle.
- Los indicadores de cantidad conocida dividen toda la fila en columnas iguales;
  no reservan columnas adaptativas vacías ni conservan anchos de mosaico.
- Las secciones con distinta cantidad de contenido se agrupan en bandas
  equilibradas o pasan a ancho completo. La interfaz evita composiciones tipo
  masonry que dejan claros sin función entre tarjetas.
- Las acciones de toolbar también están disponibles en el menú de macOS.
- Las ventanas se pueden redimensionar sin ocultar acciones críticas.

## Resumen

- La vista general deriva sus indicadores exclusivamente del grafo local:
  bloques definidos, estados, cobertura de capas, relaciones críticas y
  versiones. No presenta costos, capacidad, fechas ni aprobaciones como hechos
  mientras esos dominios no existan en el modelo.
- La lectura del ciclo conserva las cuatro macrofases del mockup aprobado:
  Iniciación, Factibilidad, Preproducción y Producción. En pantallas amplias se
  presenta como una línea horizontal con el nodo a la izquierda de cada texto;
  en ventanas estrechas adopta la misma secuencia vertical sin perder estado.
- Si existe estructura de preproducción pero no una evaluación persistida, la
  interfaz muestra Factibilidad como atención pendiente en lugar de inventar
  una aprobación o reordenar las macrofases.
- La siguiente acción enlaza con el bloque o apartado que requiere atención,
  preservando la selección al cambiar al Mapa o Arquitectura.
- Hitos, Riesgos, Actividad y Aprobaciones son proyecciones del mismo proyecto;
  cuando falta una bitácora o evaluación explícita, la interfaz lo declara en
  vez de fabricar eventos o resultados.

## Equipo, factibilidad, costos y plan de trabajo

- Mientras estos dominios no estén conectados a Project Core, cada pantalla se
  identifica como `Escenario de prototipo`. Sus personas, horas, resultados y
  cifras son datos ficticios y no se presentan como estado persistido del
  proyecto.
- Equipo separa vista general, cobertura, capacidad, asignaciones y roles
  pendientes. La sobrecarga combina porcentaje, texto e icono; nunca depende
  únicamente del color.
- Factibilidad presenta primero conclusión, confianza y condiciones. Las diez
  dimensiones, evidencias, supuestos, alternativas y aprobación permanecen en
  subvistas independientes.
- Costos separa explícitamente costo interno, precio propuesto, margen y reserva.
  El prototipo declara que la autorización por tarifas aún no está implementada;
  mostrar un icono de candado no se considera un control de acceso.
- Plan de trabajo no mezcla calendario, tablero y backlog en la misma superficie.
  El tablero permite mover tareas mediante arrastre o mediante el menú de estado
  de cada tarjeta.
- Acciones de asignación, revisión, excepción y cierre sólo modifican estado
  efímero del escenario. No simulan envíos externos ni aprobaciones persistidas.

## Cuenta y organización

- Cuenta y organización reúne Perfil, Disponibilidad, Notificaciones, Apariencia,
  Atajos de teclado, Organización, Miembros y roles, Permisos, Plantillas, Costos
  y tarifas, IA, Sincronización y Seguridad.
- Perfil y Organización siguen los dos mockups aprobados bajo
  `design/approved/mockups/account/`; las demás subvistas reutilizan su jerarquía
  de bandas, campos y paneles sin añadir una tercera barra lateral.
- Apariencia y Notificaciones son preferencias locales de esta Mac. Mientras no
  exista identidad ni Project Core, los demás apartados se identifican como
  escenarios de prototipo y sus acciones no simulan invitaciones, sesiones,
  cambios remotos ni sincronización.
- Los costos internos permanecen separados del precio al cliente. La matriz de
  permisos documenta la intención, pero no concede autoridad desde el cliente.
- IA muestra proveedor, minimización de contexto y límites antes de cualquier
  configuración de credenciales. La aplicación nunca solicita ni conserva claves
  de proveedores.
- Sincronización distingue el SQLite local de Neon y PowerSync, que aún son
  arquitectura prevista. Seguridad separa controles diseñados de controles
  realmente conectados.
- Los formularios conservan etiquetas visibles, estados expresados con texto e
  icono, y una composición adaptable de dos columnas a una columna.

## Entrada e identidad

- Antes del espacio de trabajo, Tazkle presenta una puerta de entrada nativa con
  correo como campo persistente del formulario, una acción dominante
  `Continuar con correo` y una alternativa secundaria para continuar sólo en
  esta Mac.
- El acceso remoto abre el proveedor en el navegador mediante la sesión de
  autenticación de macOS. El correo se usa como `login_hint`; Tazkle no lo
  persiste, no presenta campos de contraseña y no simula una autenticación
  propia.
- El modo local conserva el trabajo en SQLite, pero comunica de forma persistente
  que sincronización y colaboración no están habilitadas.
- Una credencial conocida sin conectividad abre el proyecto en estado
  `Sin conexión`; no se confunde con una sesión remota vigente.
- La entrada define estados de configuración pendiente, restauración, espera del
  navegador, cancelación y error recuperable. El texto y el icono acompañan
  cualquier uso de color o progreso.
- Un correo inválido conserva el valor, muestra un error ligado al campo y
  devuelve el foco para corregirlo. `Return` ejecuta la misma acción que el
  botón principal.
- Perfil y configuración → Seguridad muestra el estado efectivo de esta Mac y
  permite cerrar la sesión o volver a conectar una cuenta.

## Tazki en el espacio de trabajo

- Tazki está disponible mediante un botón flotante discreto en Resumen, Mapa del
  proyecto, Arquitectura, Equipo, Factibilidad, Costos y Plan de trabajo.
- El control usa un círculo compacto y conserva una superficie de interacción
  holgada. Sólo muestra el símbolo cian de brillos para identificar el acceso a
  IA; la mascota Tazki se reserva para el chat, sin sustituir su nombre, etiqueta
  accesible ni atajo.
- Perfil y configuración no expone el botón: identidad, permisos, tarifas
  organizacionales y seguridad no se incorporan al contexto del asistente por
  defecto.
- El botón abre el inspector nativo derecho. En Mapa y Arquitectura, cuando hay
  un bloque o una relación seleccionada, el mismo espacio ofrece las pestañas `Inspector` y
  `Tazki`; nunca aparecen dos paneles laterales compitiendo por ancho.
- Tazki explica el contexto mínimo utilizado y ofrece una alternativa propia de
  cada apartado. Comparar, preparar o descartar una alternativa sólo modifica el
  estado efímero del prototipo.
- Una variante preparada declara explícitamente que el proyecto no cambió. La
  entrada de conversación tampoco realiza tráfico mientras no exista un proveedor
  conectado.
- `⌥⌘T` abre o cierra Tazki. La selección actual también puede enviarse al panel
  desde el menú `Tazki` sin depender del botón flotante.

## Edición contextual de bloques

- Seleccionar un bloque abre un inspector compacto con identidad, descripción,
  familia, estado, estructura, relaciones y evidencia local.
- `Editar` convierte la cabecera en un formulario explícito con Guardar y
  Cancelar. Los cambios se validan como una sola operación antes de persistirse.
- Un bloque creado al arrastrar una familia desde la biblioteca se selecciona y
  abre directamente en modo edición para reemplazar su nombre y propósito
  provisionales.
- En Arquitectura, el mismo formulario incluye la capa técnica. Las relaciones
  se gestionan en una sección aparte para evitar mezclar identidad con
  dependencias.
- Los bloques aprobados no se editan en la versión vigente; requieren una nueva
  versión del proyecto.

## Edición contextual de relaciones

- Hacer clic en el recorrido, la etiqueta o la representación en lista de una
  relación la selecciona y abre el mismo inspector contextual utilizado por los
  bloques.
- El inspector describe en texto origen, tipo, destino, puertos y criticidad.
  `Editar` permite cambiar ambos extremos, los puertos de salida y entrada, el
  tipo semántico y la criticidad; Guardar valida el conjunto como una sola
  operación antes de persistirlo.
- El origen y el destino deben ser bloques distintos y una edición no puede
  duplicar otra relación con el mismo origen, tipo y destino.
- Eliminar permanece como una acción destructiva separada, con confirmación y
  recuperación mediante `⌘Z`.
- Una relación vinculada con un bloque aprobado es inmutable en la versión
  vigente y requiere una nueva versión del proyecto.

## Estados obligatorios

- Vacío.
- Cargando.
- Guardado localmente.
- Sincronizando.
- Sin conexión.
- Conflicto.
- Sin permisos.
- Datos insuficientes.
- Error recuperable.
- Resultado pendiente de aprobación.

## Prevención de errores

- Deshacer y rehacer.
- Confirmación para acciones destructivas o difíciles de revertir.
- Advertencias que indiquen causa, impacto y corrección.
- Preservación del contexto al cambiar de perspectiva.
- Comparación antes de aplicar una propuesta de Tazki.

## Organización de arquitectura

- Los bloques arquitectónicos pueden arrastrarse entre Experiencia, Servicios,
  Datos e Infraestructura; al tomar uno queda un espacio vacío discontinuo en
  su origen, la tarjeta sigue al puntero y una silueta con la etiqueta
  `Soltar aquí` ocupa el encaje real antes de confirmar el movimiento.
- Los demás bloques se redistribuyen durante el gesto para mostrar el orden final
  de la capa sin obligar a imaginar el resultado.
- Soltar sobre otro bloque lo coloca antes dentro de la misma capa. Soltar sobre
  el fondo de la capa lo coloca al final.
- La herramienta de mano desplaza el diagrama desde cualquier punto. En modo de
  selección, arrastrar el fondo también desplaza el lienzo. El trackpad y la
  rueda del mouse recorren el diagrama en ambos ejes sin activar otra herramienta.
- Un minimapa fijo en la esquina inferior izquierda representa el lienzo
  arquitectónico completo, sus bloques y el encuadre visible. Arrastrar dentro
  del minimapa cambia el encuadre sin alterar la posición de los bloques.
- El control contiguo permite acercar, alejar, volver a `100%` o ajustar el
  diagrama completo. El gesto de ampliación del trackpad y `⌘+`/`⌘−` ofrecen
  las mismas operaciones sin depender del puntero.
- El inspector, el menú contextual y las acciones semánticas permiten cambiar de
  capa sin arrastrar. La vista de lista conserva la lectura textual de capas y
  relaciones.
- Los cuatro puertos circulares del Mapa —izquierda, derecha, arriba y abajo—
  permiten iniciar relaciones también desde Arquitectura; origen, destino y
  puntos elegidos se confirman en el selector semántico.
- Arquitectura usa rutas ortogonales con stubs cortos y codos redondeados para
  expresar ensamblaje entre capas. El Mapa conserva curvas libres para representar
  asociaciones conceptuales; ambas proyecciones comparten los mismos puertos y
  tipos de relación sin duplicar el modelo.
- Las rutas aprovechan los claros entre bloques y capas como carriles, separan
  relaciones recíprocas y evitan atravesar tarjetas.
- El cableado comunica recorrido y dirección; el inspector del bloque conserva
  el tipo semántico y el detalle completo de entradas, salidas y puertos sin
  saturar el diagrama.
- Un halo del color del lienzo separa los cruces y las relaciones críticas añaden
  un patrón discontinuo, de modo que el color nunca sea la única señal.
- El cable completo y su etiqueta ofrecen clic derecho para solicitar
  `Eliminar relación`, con la misma confirmación, protección del alcance
  aprobado y recuperación mediante `⌘Z` que en el Mapa.
- Cada movimiento actualiza la versión local del bloque y se guarda en SQLite.

## Manipulación del mapa

- Las familias del catálogo se arrastran al lienzo para crear un bloque exactamente
  en el punto de caída. Activarlas con teclado abre el formulario equivalente.
- Un bloque existente se mueve en tiempo real y se eleva visualmente mientras se
  arrastra. Un espacio vacío discontinuo conserva la posición de origen, las
  relaciones siguen la ubicación temporal y una silueta marca el punto ajustado
  a la cuadrícula donde se persistirá al soltar.
- La herramienta de mano permite desplazar todo el lienzo. En modo de selección,
  el fondo conserva el mismo gesto de desplazamiento; el trackpad y la rueda del
  mouse permiten recorrerlo directamente. `⌘0` vuelve al origen.
- El Mapa dispone de un espacio lógico de trabajo mayor que la ventana. Un
  minimapa inferior izquierdo muestra la distribución completa, los bloques y
  el rectángulo del área visible; se puede arrastrar para saltar a otra región.
- Los controles del minimapa permiten `⌘+`, `⌘−`, volver a `100%` y ajustar
  todo el proyecto. El gesto de ampliación del trackpad conserva el centro del
  encuadre para evitar perder el contexto.
- Cada bloque ofrece cuatro puertos: izquierda, derecha, arriba y abajo. Arrastrar
  desde uno inicia una conexión; la línea discontinua sigue al cursor y sólo
  reconoce como destino uno de los cuatro puertos de otro bloque. El puerto válido
  se amplía y conserva los dos anclajes al terminar el drag and drop. Después se
  confirma el tipo explícito y la criticidad antes de modificar el modelo.
- Un punto permanente representa siempre una relación existente. El puerto para
  iniciar una conexión nueva se revela sólo al pasar el cursor sobre un bloque,
  al recibir foco de teclado o durante el arrastre.
- Las relaciones parten y terminan en los puertos escogidos, incluyen un nodo
  terminal en cada extremo, dirección y etiqueta. Al cruzarse, un halo del color
  del lienzo separa visualmente las líneas para indicar cuál continúa por encima.
  Mover un bloque recalcula la curva sin cambiar sus puertos. Al seleccionar un
  bloque, sus conexiones se elevan y conservan sus etiquetas mientras las ajenas
  se atenúan para poder seguir cada trayectoria en mapas densos.
- Todo el recorrido visible de una relación, además de su etiqueta, admite clic
  derecho para solicitar `Eliminar relación`. La eliminación conserva la
  confirmación, bloquea relaciones vinculadas con alcance aprobado y puede
  deshacerse con `⌘Z`.
- La toolbar, el inspector, el menú `Mapa` y la proyección de lista mantienen
  alternativas completas a todos los gestos.
- Un bloque puede eliminarse desde su menú contextual, el inspector o
  `Mapa → Eliminar bloque` (`⌫`). La confirmación indica su nombre y cuántas
  relaciones desaparecerán; `⌘Z` restaura el bloque y sus relaciones.
- Los bloques aprobados no se eliminan directamente: requieren una nueva versión
  del proyecto para preservar la trazabilidad del alcance aprobado.
