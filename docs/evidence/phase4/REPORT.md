# Bimbi · Fase 4 · Alarmas con retos

**Fecha de verificación** · 22 de noviembre de 2026, Ciudad de México. **Rama** · `codex/phase4-alarms`.

**Resultado** · PASS. Se comprobó la restauración, el límite de posposición y el retroceso de ronda con y sin silencio. El reto físico de Agitar finalizó después de 15 movimientos.

## Implementación

- **Programación local.** El editor maneja varias alarmas por identificador y guarda la hora, días, reto y dificultad en Android. Se registra cada ocurrencia exacta con `AlarmManager`. El estado guardado permite rearmar tras reiniciar y desbloquear, actualizar la app, cambiar la hora o recuperar los permisos. La migración conserva la próxima ocurrencia y la recurrencia disponible de la Fase 3. [Modelo local](../../../android/app/src/main/kotlin/com/bimbi/app/LocalAlarm.kt) · [Motor de alarmas](../../../android/app/src/main/kotlin/com/bimbi/app/AlarmEngine.kt) · [Editor](../../../lib/features/alarm/presentation/alarm_editor.dart)
- **Sesión activa.** El servicio nativo mantiene el audio y el reto al salir de la vista. Un toque, clic, acción de TalkBack o entrada del teclado reinicia la barra de 15 segundos. El vencimiento retrocede una ronda y reanuda el audio si estaba silenciado. Cada ocurrencia permite dos posposiciones exactas de cinco minutos y abre un reto nuevo al volver a sonar. [Servicio](../../../android/app/src/main/kotlin/com/bimbi/app/AlarmService.kt) · [Estado del reto](../../../android/app/src/main/kotlin/com/bimbi/app/WakeSession.kt)
- **Retos.** Agitar, Matemáticas, Ball Monte, Follow the pattern y Memorama usan cuatro dificultades que se eligen por alarma. Android muestra los retos en su vista nativa. Las alarmas simultáneas esperan su turno con sesiones separadas, incluida su propia cuenta de posposiciones. [Vista de alarma](../../../android/app/src/main/kotlin/com/bimbi/app/AlarmActivity.kt) · [Tableros y controles](../../../android/app/src/main/kotlin/com/bimbi/app/WakeRoundView.kt)

## Verificación

| Entorno | Resultado observado |
|---|---|
| Pruebas JVM de Android | 10 casos aprobados. Cubren fechas locales y cambios de horario, posposiciones, cola, actividad y vencimiento, y finalización de los cinco retos en los cuatro niveles. |
| Flutter en macOS y script de validación | Análisis limpio y 70 casos de Flutter aprobados, incluidas las referencias de **Alarms** y el editor. El script completo también aprobó 13 casos del servidor, 11 de Firebase emulado y las pruebas JVM de Android. |
| Emulador Android 16 de 412 dp | La alarma diaria de la Fase 3 conservó su próximo disparo y migró a **Math · Normal**. Quitar el permiso de alarmas exactas dejó la definición bloqueada. Al restablecerlo se registró la misma ocurrencia futura. |
| Emulador Android 16 de 360 dp | Una alarma de Matemáticas se guardó por el editor y se disparó sin conexión tras terminar el proceso. El vencimiento con silencio pasó de la ronda 3 a la 2 y reanudó el audio. El siguiente vencimiento, con audio activo, volvió a la ronda 1. Tras dos posposiciones de cinco minutos, el botón impidió una tercera y completar Matemáticas retiró la alarma. |
| Galaxy Tab A9 SM-X115, Android 16 | La alerta nativa apareció sobre la pantalla bloqueada, en modo avión y sin Wi-Fi, tras terminar el proceso. El propietario confirmó que, al silenciar y esperar 15 segundos, la alarma volvió a sonar y regresó a la ronda 1. El registro confirma que completar el reto cerró el episodio. |
| Galaxy Tab A9 tras un reinicio | Android restauró y disparó una alarma sintética de **Shake · Easy** guardada en el catálogo nativo. El propietario abrió el reto desde la notificación, usó **Snooze** y confirmó que se detuvo el sonido. Cinco minutos después volvió a sonar. El propietario completó los 15 movimientos y confirmó que se detuvo el sonido. Android retiró la ocurrencia y se restauraron los ajustes de conexión y pantalla completa. |
| Editor en Galaxy Tab A9 | Se abrió el editor con la lista de retos en vertical y horizontal. La alarma sintética se eliminó desde el editor y se restauró la orientación original. |
| Diseño con texto al 200 % | Se revisaron **Follow the pattern** de 6 × 6 a 360 dp y **Ball Monte** de seis vasos a 412 dp con datos de prueba. Las capturas conservan visibles el tablero, la barra y las acciones. [Matriz a 360 dp](pattern-360-text2x.png) · [Vasos a 412 dp](ball-monte-412-text2x.png) |
| TalkBack en Android 16 | El propietario confirmó la lectura de los retos y las dificultades en el editor de la tablet. Con TalkBack activo en el emulador, Ball Monte mostró **Use math challenge**, **Mute** y **Snooze**. La prueba de widgets verifica que las etiquetas de días y retos también exponen su acción de selección. |

[Comandos, conteos y salida de las comprobaciones](checks.txt)

## Cómo repetir el recorrido

1. Abre **Alarms**, toca **Add alarm** y elige una hora futura, **Math** y **Normal**. Guarda y verifica que Bimbi muestre la próxima hora. Puedes activar, editar o eliminar otras alarmas sin perder esa próxima ocurrencia.
2. Con alarmas exactas y notificaciones autorizadas, apaga el Wi-Fi, activa el modo avión y bloquea la pantalla. Cuando suene, resuelve hasta llegar a la ronda 3, pulsa **Mute** y espera 15 segundos. Debe volver a sonar y mostrar la ronda 2.
3. Pulsa **Snooze 5 min**. Cuando llegue el nuevo aviso, comprueba que Math empieza en la ronda 1 y muestra una posposición restante. Repite para comprobar el límite. Completa la última operación y verifica que Android retire la alerta.
4. Para comprobar la restauración, programa una alarma futura, reinicia el equipo y desbloquéalo antes de la hora. Si desactivas el permiso de pantalla completa para esta prueba, abre el reto desde la notificación y restaura el permiso al terminar.

## APK debug

```sh
flutter build apk --debug --no-pub --dart-define-from-file=config/dev.json
apksigner verify build/review/bimbi-phase4-debug.apk
shasum -a 256 build/review/bimbi-phase4-debug.apk
```

Se guardó una copia firmada en `build/review/bimbi-phase4-debug.apk`. SHA-256 `f0f0fbc478ca99e7da53ac3912584f3590d7e5b11f7aa2a231be2b12e963bea9`. [APK de desarrollo](../../../build/review/bimbi-phase4-debug.apk)

La prueba del editor, el primer disparo y las dos posposiciones en el emulador se ejecutaron con la compilación `1553dfb26b9b955646438bfdd238dd5ecd8a79c8beb13179fc9e63cd360502bd`. La prueba física de Matemáticas se hizo con `7fa0199eeb0ddd4b7500a8bffc4bc6fe39e43f564fae1fa6210883957e38f715` y la de reinicio con `477a043f924c8aa7299d56fc88ab6beca1aaa9c4ab75a01ada5615fda6a0d0ef`. Las capturas con texto ampliado y la revisión física del editor se completaron con `b08deb1f183e454056651eb5d5974f37ecfff6a317f3147b75591b9fc7bffabc`. El APK de entrega añadió las acciones de accesibilidad para seleccionar días y retos y pasó nuevamente la suite de Flutter.
