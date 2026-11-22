# Bimbi · Cómo se implementó y validó la Fase 2

La Fase 2 partió del APK de viabilidad de la Fase 1 y le dio a Bimbi una interfaz adaptable, un sistema visual compartido y un primer flujo de uso para cada pestaña. La primera implementación siguió el kit de identidad de Bimbi. Después se ajustaron la navegación y las pantallas con las referencias visuales del usuario. El prototipo **Wake** sirvió para decidir la tipografía y la paleta de la versión final. El cierre visual quedó registrado el **22 de noviembre de 2026** en la rama local `feat/phase2-design-system`. [Punto de partida en la Fase 1](../phase1/IMPLEMENTACION_FASE_1.md) · [Informe de la Fase 2](REPORT.md) · [Decisión de cierre](../../decisions/gates.md)

## 1. Partir del armazón de Android

Se tomó como base el commit `1f025ed`, que conserva las pruebas de viabilidad de la primera fase. Así, las nuevas pantallas pudieron reutilizar la alarma de Kotlin, los adaptadores de autenticación, las notificaciones, el mapa, el seguimiento y los pagos de prueba. El identificador de la app siguió siendo `com.bimbi.app`. La versión fijada para Flutter fue **3.47.5** y el mínimo de Android fue **API 26**. [Configuración de Flutter](../../../.fvmrc) · [Módulo Android](../../../android/app/build.gradle.kts) · [Arquitectura](../../ARCHITECTURE.md)

## 2. Crear el tema compartido y los componentes

Primero se tradujo el kit visual a constantes de color, espaciado, bordes, tipografía y movimiento en `bimbi_tokens.dart`. Sobre esas constantes, `BimbiColors` asigna colores por función, como fondo, tarjeta, texto, enlace y selección. `BimbiTheme` construye los temas Material 3 claro y oscuro que consumen las pantallas. La primera versión usaba mandarina, crema e índigo, con **Fredoka** para los títulos y números y **Nunito** para la interfaz. [Constantes del tema](../../../lib/app/theme/bimbi_tokens.dart) · [Roles de color](../../../lib/app/theme/bimbi_colors.dart) · [Tema Material](../../../lib/app/theme/bimbi_theme.dart)

Se extrajeron piezas reutilizables para que un mismo ajuste se reflejara en varias pantallas. `surfaces.dart` contiene encabezados, tarjetas y avisos con estados. `alarm_parts.dart` formatea las horas y dibuja los días del editor. `data_parts.dart` aporta el resumen semanal y las tarjetas de planes. La galería de desarrollo permite revisarlas en ambos temas con datos de ejemplo. [Superficies](../../../lib/app/design_system/components/surfaces.dart) · [Componentes de alarma](../../../lib/app/design_system/components/alarm_parts.dart) · [Componentes de datos](../../../lib/app/design_system/components/data_parts.dart) · [Galería](../../../lib/app/developer/design_gallery.dart)

## 3. Preparar el arranque y la bienvenida

`main.dart` carga las preferencias locales y las inyecta en Riverpod mediante `ProviderScope`. `BimbiApp` aplica el tema elegido y decide entre mostrar la bienvenida de cuatro pasos o abrir las pestañas, según el valor de `onboardingProvider`. La bienvenida permite avanzar, retroceder u omitirla. Al terminar se pueden guardar el nombre visible y el color de la mascota. La app guarda esas preferencias, el modo de apariencia y el indicador de bienvenida en `SharedPreferences`. [Arranque](../../../lib/main.dart) · [BimbiApp](../../../lib/app/bimbi_app.dart) · [Bienvenida](../../../lib/features/onboarding/onboarding_page.dart) · [Preferencias locales](../../../lib/app/preferences.dart)

Los controles de diagnóstico de la Fase 1 se agruparon en **Profile → Developer tools**. `AppConfig.harness` combina el modo de depuración con la opción de compilación `PHASE1_HARNESS`. El arranque sólo intenta inicializar Firebase cuando ese modo está activo y hay configuración. Si la inicialización falla, la app puede seguir abriendo la interfaz y usando la alarma local. [Configuración de desarrollo](../../../lib/core/config.dart) · [Herramientas de desarrollo](../../../lib/app/developer/developer_tools.dart)

## 4. Adaptar las cinco pestañas al tamaño de la ventana

`AdaptiveShell` mide el ancho con `LayoutBuilder`. La decisión usa píxeles lógicos, por lo que el diseño responde al espacio disponible al girar la tablet o cambiar el tamaño de la ventana. El cálculo en `WindowClass.fromWidth` es el siguiente. [Clasificación y componentes de distribución](../../../lib/app/shell/layout.dart)

```dart
static WindowClass fromWidth(double width) {
  if (width < 600) return WindowClass.compact;
  if (width < 840) return WindowClass.medium;
  return WindowClass.expanded;
}
```

| Ancho disponible | Distribución |
|---|---|
| Menos de 600 dp | Barra inferior flotante y una columna |
| Desde 600 hasta menos de 840 dp | Barra lateral con etiquetas y una columna |
| 840 dp en adelante | Barra lateral y dos paneles con desplazamiento independiente |

El orden de **Alarms**, **Sleep**, **Focus**, **Running** y **Profile** conserva los índices que usa el enrutamiento de notificaciones. Desde cualquiera de las otras pestañas, el botón Atrás vuelve a **Alarms** antes de salir de la app. Al salir de **Running** o mandar Bimbi a segundo plano, el armazón detiene el seguimiento. Cuando se vuelve a la app, actualiza las capacidades y los permisos de Android. [Navegación](../../../lib/app/shell/adaptive_shell.dart) · [Enrutamiento de notificaciones](../../../lib/features/notifications/messaging.dart)

## 5. Dibujar y animar la mascota del proyecto

Se trasladaron las formas del reloj del kit a `BuddyPainter`, un `CustomPainter` que compone el cuerpo, las campanas y el rostro en un lienzo lógico de 320 × 320. `BuddyPalette.from` recibe un color base y deriva los tonos del degradado a partir del tono, la saturación y la luminosidad. `MoodScript` interpola las poses de seis expresiones y de la secuencia de despertar. `BimbiBuddy` conecta el color guardado con esas piezas y muestra una pose estática cuando Android tiene las animaciones desactivadas. La mascota se excluye de la lectura de pantalla cuando cumple una función decorativa. [Dibujo](../../../lib/app/design_system/buddy/buddy_painter.dart) · [Derivación de color](../../../lib/app/design_system/buddy/buddy_palette.dart) · [Animaciones](../../../lib/app/design_system/buddy/buddy_motion.dart) · [Widget](../../../lib/app/design_system/buddy/bimbi_buddy.dart)

## 6. Conectar Alarms con la programación nativa

`HomeScreen` muestra el saludo, la fecha, la próxima alarma y el promedio reciente del diario. `homeViewModelProvider` deriva estos datos de varios proveedores y toma la hora pendiente de las capacidades de Android. Si el dispositivo no tiene una alarma programada, la tarjeta ofrece **Set alarm**. En la interfaz de cierre, `openEditor` abre `AlarmEditorPage` como una ruta propia en todos los anchos. En la vista amplia, la tarjeta de próxima alarma y la lista de alarmas ocupan columnas separadas. [Vista Alarms](../../../lib/ui/home/widgets/home_screen.dart) · [Modelo de la vista](../../../lib/ui/home/view_models/home_view_model.dart) · [Editor](../../../lib/features/alarm/presentation/alarm_editor.dart)

Al guardar, `AlarmDraft.nextOccurrence` busca la primera fecha futura que coincide con la hora y los días elegidos. Se mantuvo una sola ocurrencia pendiente. Elegir los siete días activa un intervalo nativo de 24 horas. Una selección parcial programa la siguiente coincidencia. `SavedAlarmController` guarda los detalles de la sesión después de que Android acepta la operación y vuelve a consultar el estado real. La misma clase cancela la alarma por el canal nativo y limpia esos detalles. [Borrador y controlador](../../../lib/features/alarm/application/alarm_draft.dart) · [Adaptador del canal](../../../lib/core/platform.dart) · [Cálculo de ocurrencias probado](../../../test/unit/alarm_draft_test.dart)

```dart
Future<DateTime> schedule(AlarmDraft draft) async {
  final at = draft.nextOccurrence(ref.read(clockProvider)());
  await ref
      .read(platformProvider)
      .schedule(id: bimbiAlarmId, at: at, repeat: draft.nativeRepeat);
  state = draft;
  ref.invalidate(capabilitiesProvider);
  return at;
}
```

## 7. Llevar el diseño a la alerta nativa y al inicio de Android

`AlarmActivity.kt` construye la vista de despertar en Kotlin con la hora local, la mascota y un botón **Dismiss alarm** de al menos 72 dp. El botón llama a `AlarmEngine.dismiss()`, que limpia la alarma activa, detiene el servicio y retira la notificación. La alerta puede aparecer sobre la pantalla bloqueada con el mecanismo nativo de Android. También se mantuvo la ruta de compatibilidad de Android 8.0 con las banderas de ventana. [Actividad de alarma](../../../android/app/src/main/kotlin/com/bimbi/app/AlarmActivity.kt) · [Programación y descarte](../../../android/app/src/main/kotlin/com/bimbi/app/AlarmEngine.kt) · [Servicio de alarma](../../../android/app/src/main/kotlin/com/bimbi/app/AlarmService.kt)

Para llevar la misma mascota a la pantalla nativa y al icono de inicio, se ejecutó `python3 scripts/generate_native_buddy.py android/app/src/main/res`. El script genera recursos `VectorDrawable` a partir de la geometría del reloj. Android usa esos vectores en el icono adaptable y en la alerta. La actividad de alarma carga sus fuentes desde `res/font`. El manifiesto y el servicio referencian el icono y el color de notificación. La primera versión de la alerta se probó con la pantalla bloqueada y se verificó el descarte. La última versión con los recursos lavanda se compiló en el APK de cierre. [Generador](../../../scripts/generate_native_buddy.py) · [Colores nativos](../../../android/app/src/main/res/values/colors.xml) · [Icono adaptable](../../../android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml) · [Captura de la prueba original](tablet-native-wake-screen.png)

## 8. Implementar Sleep y su diario

`SleepPage` combina el resumen de la última entrada, las barras de la semana y el listado del diario. El formulario pide hora de acostarse y hora de despertar. `entryFromTimes` ajusta la fecha de acostarse al día anterior cuando cruza medianoche. `SleepDiaryController.save` reemplaza la entrada si ya existe una para el mismo día de despertar y ordena las demás de la más reciente a la más antigua. La duración que se muestra es **tiempo en cama**, calculada a partir de las horas ingresadas. Los datos de esta fase viven en memoria. [Pantalla y formulario](../../../lib/features/sleep/presentation/sleep_page.dart) · [Modelo del diario](../../../lib/features/sleep/application/sleep_diary.dart) · [Pruebas del diario](../../../test/unit/sleep_diary_test.dart)

## 9. Implementar Focus y ajustar el dial en horizontal

`FocusDial` usa `CustomPainter` para dibujar la pista, las marcas y el arco. Al arrastrarlo convierte la posición del dedo en un ángulo y el controlador ajusta la duración a pasos de cinco minutos, entre 5 y 120. El dial también ofrece acciones semánticas para aumentar o disminuir el valor. `FocusSession` calcula el tiempo restante a partir del instante de inicio y la duración acumulada antes de una pausa. El pulso de un segundo actualiza la pantalla; el cálculo se rehace con la hora actual. En esta fase la sesión permanece en memoria. [Dial](../../../lib/features/focus/presentation/focus_dial.dart) · [Estado del temporizador](../../../lib/features/focus/application/focus_session.dart) · [Pruebas de Focus](../../../test/unit/focus_session_test.dart)

Durante la revisión en tablet se ajustó el tamaño del dial con la altura útil, después de que la app reserva espacio para las barras de Android. El selector circular y **Start focus** quedaron dentro de la misma tarjeta. En el ensayo horizontal del refinamiento, el botón quedó completo en pantalla y midió 69 px de alto. La consulta opcional de **Usage Access** se muestra aparte y el temporizador funciona con el permiso apagado. [Distribución de Focus](../../../lib/features/focus/presentation/focus_page.dart) · [Registro físico del ajuste](revision-tablet-check.txt)

## 10. Integrar el mapa y el seguimiento de Running

La pantalla usa el mapa nativo cuando Android informa que la integración está configurada. Carga el estilo según el tema, dibuja el marcador de Chapultepec y traza una polilínea con las muestras aceptadas. `RouteSummary` suma las distancias entre puntos y calcula el tiempo entre la primera y la última muestra. Junto a los botones de seguimiento se muestran esos valores, el número de muestras y la precisión de la más reciente. El adaptador solicita ubicación en uso y omite muestras simuladas o con más de 50 m de error estimado. Al terminar se detiene el GPS y se mantiene el trazo en memoria para revisarlo. [Pantalla y resumen de ruta](../../../lib/features/running/presentation/running_page.dart) · [Adaptador y filtro de muestras](../../../lib/features/running/tracking.dart) · [Estilos del mapa](../../../assets/map/) · [Pruebas de seguimiento](../../../test/unit/tracking_test.dart)

## 11. Organizar Profile y reutilizar los servicios existentes

Las opciones se agruparon en **Account**, **Appearance**, **Permissions**, **Plans** y **Privacy**. En ventanas compactas y medianas cada opción abre su detalle. En ventanas amplias la lista permanece junto al detalle. **Appearance** modifica el nombre local, el tema y la mascota. **Permissions** muestra el estado de los permisos y abre el ajuste correspondiente de Android. [Menú y secciones de Profile](../../../lib/features/profile/presentation/profile_page.dart) · [Estado de capacidades](../../../lib/core/capabilities.dart)

**Account** conecta los formularios e inicio de sesión con los adaptadores ya probados en la Fase 1. **Plans** presenta Free, Plus y Premium y habilita la prueba de pago sólo cuando Firebase está listo y la cuenta tiene correo verificado. El pago sigue en Stripe Sandbox y su resultado se verifica por el servidor. [Adaptador de autenticación](../../../lib/features/auth/auth_adapter.dart) · [Adaptador de pago](../../../lib/features/payments/payment_adapter.dart) · [Pruebas físicas de la primera fase](../phase1/REPORT.md)

## 12. Revisar el diseño y construir Wake como sexta pestaña temporal

Tras revisar el kit y las capturas, se simplificaron las tarjetas de **Alarms**, el dial de **Focus** y el menú de **Profile**. La revisión conservó cinco destinos principales y los refinó en la barra flotante y la barra lateral. Después se creó **Wake** desde cero como una sexta pestaña para evaluar una propuesta inspirada en la ligereza visual de Tiimo. Tenía una composición de amanecer dibujada en Flutter, superficies lavanda y la fuente **Instrument Serif** tanto en el título como en la hora. [Primera revisión visual](REFINAMIENTO_VISUAL.md#primera-iteración-visual)

El prototipo vivió temporalmente en `lib/features/alarm/presentation/wake_page.dart`. Abría un selector de hora, permitía elegir una vez o a diario y reutilizaba el mismo identificador `bimbi-alarm` de **Alarms**. Para conectar ambas interfaces se centralizaron la programación y la cancelación en el controlador del paso 6. En esa compilación se abrió **Wake** y su selector en la Galaxy Tab A9. La decisión visual final fue aplicar ese aspecto a las pantallas permanentes. [Controlador compartido que quedó en el proyecto](../../../lib/features/alarm/application/alarm_draft.dart)

## 13. Aplicar la versión lavanda, cambiar los iconos y retirar Wake

Se trasladaron los colores de **Wake** al tema global. En claro se eligieron el fondo `#F3ECFA`, los matices `#ECE1F8` y el botón ciruela `#5D437A` con texto blanco. En oscuro se usaron el fondo `#191421` y el acento `#E3C9F5` con texto ciruela. Por usar roles compartidos, el cambio llegó a tarjetas, botones, barra inferior, barra lateral y estados seleccionados. Se actualizó también el juego de colores de Android. [Paleta final](../../../lib/app/theme/bimbi_tokens.dart) · [Contraste y tipografía](../../../test/unit/design_tokens_test.dart) · [Recursos Android](../../../android/app/src/main/res/values/colors.xml)

Se asignó **Instrument Serif** a los títulos y números grandes del tema, al reloj y a la alerta Kotlin. **Nunito** quedó en el texto de interfaz, los botones y el indicador AM/PM. Se empaquetaron las fuentes y licencias SIL OFL en `assets/fonts`. Se reemplazaron los SVG iniciales por **38 PNG originales** de Claude Hand Drawn. Cada valor de `BimbiIcons` indica qué archivo muestra el widget. Se usó un fondo claro en las superficies oscuras para que se vieran los trazos. El enlace **Icons by Icons8** quedó en **Profile**. [Recursos declarados](../../../pubspec.yaml) · [Formato de la hora](../../../lib/app/design_system/components/alarm_parts.dart) · [Iconos de la app](../../../lib/app/design_system/bimbi_icon.dart) · [Decisión sobre fuentes e iconos](../../adr/008-design-assets.md) · [Colección de Icons8](https://iconos8.es/icons/claude-hand-drawn)

El cambio a **lila por defecto** se hizo en `BuddyColorController`. Si la persona ya eligió un color, se recupera esa preferencia. Con el mismo lila se regeneraron la mascota nativa y el icono de inicio. Por último se retiraron el archivo, la ruta y las referencias visuales automatizadas de **Wake**. La interfaz quedó con cinco pestañas, y el editor permanente de **Alarms** usa el controlador compartido. [Preferencia lila](../../../lib/app/preferences.dart) · [Bienvenida probada](../../../test/onboarding_test.dart) · [Navegación final](../../../lib/app/shell/adaptive_shell.dart) · [Captura final en la tablet](cierre-lavanda-tablet.png)

## 14. Verificar cada compilación y entregar el APK

Las pruebas de interfaz usan un reloj fijo y un adaptador en memoria para comprobar que guardar una alarma envía la fecha esperada sin hacer sonar Android. La matriz recorre cuatro anchos (360, 412, 700 y 900 dp), tres escalas de texto (1, 1,3 y 2) y dos temas. Las pruebas visuales cargan las fuentes del APK y comparan la interfaz con imágenes de referencia renderizadas en macOS. [Ayudas de prueba](../../../test/helpers/pump.dart) · [Pruebas de widgets](../../../test/widget_test.dart) · [Referencias visuales](../../../test/golden/screens_golden_test.dart)

| Etapa | Resultado registrado |
|---|---|
| Primera implementación del sistema de diseño | `scripts/check.sh` terminó con código 0. La salida conserva 67 pruebas de Flutter, 11 pruebas del servidor y seis casos de emuladores de Firebase. [Salida conservada](check-summary.txt) |
| Primer refinamiento de las pantallas | 69 pruebas de Flutter. Los emuladores Android de 360 y 412 dp recorrieron las cinco pestañas. En la Galaxy Tab A9 se revisaron ambas orientaciones y el flujo de Focus. [Teléfono 360 dp](phone-360-test.txt) · [Teléfono 412 dp](phone-412-test.txt) · [Registro de tablet](revision-tablet-check.txt) |
| Prototipo Wake | 71 pruebas de Flutter durante la versión de seis pestañas. Las dos pruebas adicionales verificaban el flujo exclusivo de **Wake**. |
| Cierre lavanda | El análisis terminó sin hallazgos y pasaron 69 pruebas de Flutter. Se compiló e instaló el APK conservando los datos de Bimbi. Se abrieron las cinco pestañas en vertical en la Galaxy Tab A9. [Registro de cierre](REFINAMIENTO_VISUAL.md#cierre-con-el-tema-lavanda) · [Captura física](cierre-lavanda-tablet.png) |

Para repetir las comprobaciones locales desde la raíz del proyecto, se usa Flutter 3.47.5 y un `config/dev.json` local preparado según la guía de configuración. La instalación con `-r` conserva los datos si el APK se firma con la misma clave. Cuando hay varios dispositivos conectados, se usa `adb -s <identificador> install -r ...` para elegir uno. [Guía de configuración](../../SETUP.md) · [Script de comprobación integral](../../../scripts/check.sh)

```sh
flutter pub get
flutter analyze --no-pub --fatal-infos
flutter test --no-pub --reporter expanded
flutter build apk --debug --no-pub --dart-define-from-file=config/dev.json
shasum -a 256 build/app/outputs/flutter-apk/app-debug.apk
adb devices
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Los perfiles de teléfono se pueden repetir con `./scripts/test_phone_profile.sh 360` y `./scripts/test_phone_profile.sh 412` tras preparar los emuladores y `ANDROID_HOME`. Las pruebas de integración usan su propio punto de entrada y pueden generar un APK en la ruta habitual de salida. Por eso se recompila la app con `lib/main.dart` para la entrega. [Creación de perfiles](../../../scripts/create_phone_emulators.sh) · [Ejecución en teléfono](../../../scripts/test_phone_profile.sh) · [Prueba de integración](../../../integration_test/shell_test.dart)

El APK de cierre se generó en `build/app/outputs/flutter-apk/app-debug.apk`. Su SHA-256 es `17bfa628dee330985132cf553d1f314d50fc1f71f7479cc041c70cd254cc01d8`. La activación con pantalla bloqueada corresponde a una compilación anterior. Para este APK quedan pendientes un nuevo disparo físico de la alarma y el recorrido hablado con **TalkBack**. El cierre documenta el alcance visual acordado y deja registradas esas verificaciones. [Historial de sumas](apk-sha256.txt) · [Estado de las fases](../../decisions/gates.md) · [Límites de la Fase 2](../../LIMITATIONS.md)
