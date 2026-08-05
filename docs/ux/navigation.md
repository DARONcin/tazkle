# Navegación y estructura de interfaz

## Navegación principal

- Resumen.
- Mapa del proyecto.
- Arquitectura.
- Equipo.
- Factibilidad.
- Costos.
- Plan de trabajo.
- Configuración.

El catálogo de bloques aparece únicamente en Mapa del proyecto y Arquitectura. Las demás áreas usan filtros, resúmenes e inspectores apropiados para reducir saturación.
Configuración no compite con las áreas del proyecto: se presenta como una
acción fija e inequívoca en el extremo inferior de la sidebar. La identidad
activa aparece como contexto secundario, sin sustituir el nombre del destino.

## Proyectos y creación

- Una cuenta sin proyectos abre una bienvenida independiente del espacio de
  trabajo. No muestra sidebar, inspector ni un proyecto ficticio. Su acción
  dominante es `Crear nuevo proyecto` y la secundaria abre un recorrido breve
  por mapa, arquitectura, factibilidad y cotización.
- El recorrido también permanece disponible desde `Ayuda de Tazkle` y termina
  ofreciendo iniciar el asistente de creación. Puede cerrarse en cualquier paso
  y respeta Reducir movimiento.
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
- Versiones anteriores podían persistir automáticamente un marcador vacío
  `Proyecto sin nombre`. Sólo se retira cuando es el único registro, usa lienzo
  vacío, no tiene bloques, relaciones ni perfil de planeación; cualquier
  proyecto con contenido o perfil se conserva.

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

- Equipo ya lista miembros reales desde Project Core (persona, rol, estado de
  acceso); cobertura, capacidad y asignaciones siguen sin dominio real detrás,
  así que muestran un estado "sin datos conectados" en vez de cifras
  inventadas.
- Factibilidad presenta primero conclusión, confianza y condiciones — esa
  parte y las diez dimensiones son cálculo local real desde el grafo y el
  perfil de planeación guardados. Evidencias, supuestos, alternativas y
  aprobación todavía no tienen dominio real: cada subvista lo declara en vez
  de simular fuentes, condiciones o una persona responsable.
- Costos separa explícitamente costo interno, precio propuesto, margen y
  reserva; el resumen, el desglose por rol y la propuesta son cálculo local
  real. Costo por módulo, servicios/licencias e historial del presupuesto
  todavía no tienen dominio real y muestran el mismo estado "sin datos
  conectados".
- Plan de trabajo no tiene todavía un dominio de tareas, sprints ni tablero en
  Project Core: cada subvista (resumen, calendario, tablero, backlog,
  entregables, aprobaciones) declara explícitamente que está pendiente en vez
  de simular un sprint, fechas o responsables.

## Cuenta y organización

- Configuración reúne Perfil, Seguridad, Disponibilidad, Notificaciones, Apariencia,
  Atajos de teclado, Organización, Miembros y roles, Permisos, Plantillas, Costos
  y tarifas, IA, Sincronización y Seguridad.
- Perfil y Organización siguen los dos mockups aprobados bajo
  `design/approved/mockups/account/`; las demás subvistas reutilizan su jerarquía
  de bandas, campos y paneles sin añadir una tercera barra lateral.
- Apariencia y Notificaciones son preferencias locales de esta Mac. Miembros y
  roles y Costos y tarifas ya consultan Project Core (lectura real en ambas;
  escritura real sólo en Costos y tarifas, restringida a organization-admin).
  Mientras el resto de los apartados no esté conectado, se identifican como
  escenarios de prototipo y sus acciones no simulan invitaciones, sesiones,
  cambios remotos ni sincronización.
- Los costos internos permanecen separados del precio al cliente. Organización,
  Disponibilidad, Permisos, Plantillas, IA y Sincronización todavía no tienen
  dominio real detrás; cada una declara "sin datos conectados" en vez de
  simular una matriz de permisos, un proveedor de IA o un estado de
  sincronización. Seguridad separa controles diseñados de controles realmente
  conectados.
- Los formularios conservan etiquetas visibles, estados expresados con texto e
  icono, y una composición adaptable de dos columnas a una columna.

## Entrada e identidad

- Antes del espacio de trabajo, Tazkle presenta una puerta de entrada nativa con
  una acción dominante `Crear cuenta`, una acción secundaria `Iniciar sesión`
  y ninguna ruta de acceso anónima.
- El acceso remoto abre directamente el registro o el inicio de sesión
  correspondiente mediante la sesión de autenticación de macOS. Nombre, correo
  y contraseña se capturan una sola vez en la pantalla alojada por Identity;
  Tazkle no duplica esos campos ni simula una autenticación propia.
- El trabajo sin conexión sólo está disponible después de validar una cuenta en
  esa Mac. Una credencial y una identidad conocidas abren su propio espacio en
  estado `Sin conexión`; no se confunden con una sesión remota vigente.
- Cada pareja emisor + `sub` OIDC recibe un archivo SQLite separado mediante un
  identificador derivado no reversible. Cambiar de cuenta no importa ni mezcla
  automáticamente proyectos de otro espacio.
- Si falta conectividad antes del primer acceso, la puerta permanece cerrada.
  Los cambios offline se conservan localmente; la sincronización con Project
  Core sigue marcada como pendiente en el corte funcional actual.
- `Configuración → Seguridad` separa `Cerrar sesión en esta Mac` de
  `Eliminar cuenta`. La segunda acción sólo se habilita online, muestra una
  confirmación destructiva, fuerza una nueva autenticación de la misma cuenta
  y después abre Identity para escribir `ELIMINAR`. Una cuenta distinta se
  rechaza sin alterar la sesión activa. El regreso a la app sólo ocurre cuando
  Identity confirma que la identidad remota ya no existe; si no puede
  comprobarlo, muestra un error y conserva el espacio local. Cancelar
  cualquiera de los pasos conserva la sesión y los datos.
- La entrada define estados de configuración pendiente, restauración, espera del
  navegador, cancelación y error recuperable. El texto y el icono acompañan
  cualquier uso de color o progreso.
- Los errores de los datos de cuenta se muestran junto al formulario alojado,
  preservan los valores recuperables y permiten corregirlos sin reiniciar la
  autorización. `Return` envía el formulario correspondiente.
- Crear una cuenta cambia dentro de la misma ventana a un campo de seis dígitos
  con `autocomplete=one-time-code`; el correo se presenta enmascarado y el foco
  se mueve al código. Al verificarlo, la persona debe guardar los códigos de
  recuperación antes de volver a Tazkle.
- El alta solicita el código de forma explícita antes de mostrar ese paso y
  comunica que la entrega puede tardar. Un reenvío invalida el código anterior
  y pide utilizar únicamente el mensaje más reciente.
- Si el correo ya pertenecía a una cuenta, el sistema no lo revela antes de
  comprobar el OTP. Después de verificarlo, una contraseña que no coincide
  cierra la sesión provisional y explica que el código sí fue correcto, con una
  acción directa para iniciar sesión usando la contraseña vigente.
- Iniciar sesión con contraseña no crea una sesión remota hasta completar el
  segundo código. Reenvío, expiración, intentos agotados y bloqueo temporal se
  comunican mediante texto y una región viva, no sólo mediante color.
- La pantalla alojada no confía esta Mac automáticamente. Los accesos sociales
  delegan el segundo factor al proveedor correspondiente.
- Configuración → Seguridad muestra el estado efectivo de esta Mac y
  permite cerrar la sesión o volver a conectar una cuenta.

## Tazki en el espacio de trabajo

- Tazki está disponible mediante un botón flotante discreto en Resumen, Mapa del
  proyecto, Arquitectura, Equipo, Factibilidad, Costos y Plan de trabajo.
- El control usa un círculo compacto y conserva una superficie de interacción
  holgada. Sólo muestra el símbolo cian de brillos para identificar el acceso a
  IA; la mascota Tazki se reserva para el chat, sin sustituir su nombre, etiqueta
  accesible ni atajo.
- Configuración no expone el botón: identidad, permisos, tarifas
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
