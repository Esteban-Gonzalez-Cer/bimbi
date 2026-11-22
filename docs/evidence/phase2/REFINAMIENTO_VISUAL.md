# Refinamiento visual de Bimbi · 22 de noviembre de 2026

## Cierre con el tema lavanda

La revisión de **Wake** definió la paleta de las cinco pestañas. Se aplicaron lavanda, ciruela y superficies oscuras a los controles de Flutter y a la alarma nativa. Instrument Serif se usa en títulos y números grandes, con Nunito para el texto y los controles. La mascota arranca en lila y conserva el color elegido por cada persona. La pestaña experimental **Wake** se retiró después de trasladar su estilo.

- Los 38 iconos de interfaz usan los PNG originales de **Claude Hand Drawn**. El crédito está enlazado desde **Profile**. [Colección de Icons8](https://icons8.com/icons/claude-hand-drawn)
- `flutter analyze --no-pub --fatal-infos` terminó sin hallazgos. `flutter test --no-pub --reporter expanded` aprobó **69 pruebas**. Las pruebas cubren temas claro y oscuro, navegación a 360, 412, 700 y 900 dp con texto ampliado, y el preset lila.
- `flutter build apk --debug --no-pub --dart-define-from-file=config/dev.json` generó el APK. La actualización conservó los datos de la **Galaxy Tab A9** y se abrieron las cinco pestañas desde la navegación lateral en vertical. [Captura de Focus](cierre-lavanda-tablet.png)

El APK de cierre se encuentra en `build/app/outputs/flutter-apk/app-debug.apk`. Su SHA-256 es `17bfa628dee330985132cf553d1f314d50fc1f71f7479cc041c70cd254cc01d8`. El recorrido hablado con TalkBack y una nueva activación de la alarma nativa quedan como verificaciones pendientes de esta compilación.

## Primera iteración visual

El kit proporcionado define la identidad de Bimbi. Esta versión usaba la mascota del proyecto, mandarina para las acciones, crema en modo claro e índigo en modo oscuro. Fredoka se aplica a títulos y números, y Nunito a controles y texto. Las dos fuentes y sus licencias están dentro del APK. Las capturas de referencia guiaron el espacio entre tarjetas, la navegación flotante y el protagonismo del dial.

- **Alarms** muestra la fecha local y la hora real de la próxima alarma. Cuando falta una alarma, ofrece un acceso directo a **Set alarm** y un estado vacío sin una hora de ejemplo. [Código de Alarms](../../../lib/ui/home/widgets/home_screen.dart) · [Vista de teléfono](../../../test/golden/goldens/alarm_360_light.png)
- **Focus** coloca el dial con marcas y su acción principal en la misma tarjeta. El dial se adapta al espacio útil que deja Android para mantener **Start focus** visible en la Galaxy Tab A9 horizontal. [Código de Focus](../../../lib/features/focus/presentation/focus_page.dart) · [Vista de teléfono](../../../test/golden/goldens/focus_412_light.png)
- **Profile** agrupa cuenta, apariencia, permisos, planes y privacidad. Cada grupo abre su propia pantalla en anchos compactos y medios. En la vista amplia, el grupo y su detalle se muestran juntos. [Código de Profile](../../../lib/features/profile/presentation/profile_page.dart) · [Vista de teléfono](../../../test/golden/goldens/profile_412_light.png)
- La barra flotante mantiene los cinco destinos con icono y texto en teléfonos. A partir de 600 dp aparece una barra lateral. [Código de navegación](../../../lib/app/shell/adaptive_shell.dart)

## Comprobaciones

- Análisis de Flutter sin hallazgos y **69 pruebas aprobadas**, incluidas las referencias visuales, los tamaños de texto y un caso de regresión para **Start focus** en una vista horizontal corta.
- Recorrido por los cinco destinos en emuladores Android de **360 y 412 dp**. Se realizaron las pruebas de integración antes de generar el APK de la app.
- Instalación sobre Bimbi en la **Samsung Galaxy Tab A9**, con conservación de datos. En horizontal, **Start focus** quedó completamente visible y midió 69 píxeles de alto. El registro de la tablet documenta las acciones y la revisión física en vertical y horizontal. [Registro de la tablet](revision-tablet-check.txt) · [Focus en vertical](revision-focus-vertical.png) · [Focus en horizontal](revision-focus-horizontal.png)

El SHA-256 de esa compilación fue `c7b33349de1f1592000eba451d275c178cc9d4bc6f5cb40d80754d95efa2156f`. El recorrido manual con TalkBack sigue pendiente en el cierre de la Fase 2. [Informe de la Fase 2](REPORT.md)
