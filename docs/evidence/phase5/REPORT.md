# Bimbi · Fase 5 · Sueño y Focus

**Fecha de verificación** · 22 de noviembre de 2026, Ciudad de México. **Rama** · `codex/phase5-sleep-focus`, desde `0cc2163`.

**Resultado** · CONDITIONAL PASS. El diario de sueño y Focus se guardan en el dispositivo y sobreviven a que Android termine la app. Las cuentas verificadas sincronizan con Realtime Database. Las pantallas Sleep, Focus y Focus shield se aprobaron una por una. El escudo de Focus y los límites diarios funcionaron en el emulador y en la tablet. Quedan cinco comprobaciones del propietario, listadas al final.

## Implementación

- **Datos en el dispositivo primero.** `CollectionController` guarda cada fila en `SharedPreferences`, la marca como pendiente y conserva las eliminaciones hasta que la nube las confirma. `CollectionSync` adopta los datos de invitado en la primera cuenta verificada y nunca los pasa a otra cuenta. Fusiona la copia de la nube y envía los cambios pendientes al recuperar la conexión. [Colección local](../../../lib/data/repositories/local_collection.dart) · [Sincronización](../../../lib/data/repositories/collection_sync.dart) · [Reglas](../../../firebase/database.rules.json)
- **Diario de sueño.** Cada noche guarda la hora de acostarse y de despertar como instantes, con la clave de la fecha local en que despertó. Así, una noche con cambio de horario reporta el tiempo real en cama. La hoja de registro sugiere la hora de despertar de la alarma completada hoy y muestra sus posposiciones. [Modelo](../../../lib/domain/models/sleep_entry.dart) · [Diario](../../../lib/ui/sleep/view_models/sleep_diary.dart) · [Registro nativo de la alarma](../../../android/app/src/main/kotlin/com/bimbi/app/AlarmEngine.kt)
- **Focus.** La sesión se guarda en cada cambio y se reconstruye desde marcas de tiempo (FOCUS-01).
  - El anillo avanza en pasos de 5 minutos; cada vuelta son 2 h, hasta cuatro vueltas, y al tocar el número se escriben minutos exactos.
  - Una sesión puede dividirse en ventanas.
  - Al terminar, se registra si duró al menos un minuto. [Sesión](../../../lib/ui/focus/view_models/focus_session.dart) · [Anillo](../../../lib/ui/focus/widgets/focus_dial.dart)
- **Sonidos.** `FocusChime` registra un sonido suave al final de cada ventana y un destello al terminar la sesión. Se cancelan al pausar o terminar. Los sonidos se generan con un script, sin grabaciones. [Sonidos nativos](../../../android/app/src/main/kotlin/com/bimbi/app/FocusChime.kt) · [Generador](../../../scripts/generate_focus_sounds.py)
- **Escudo de Focus y límites diarios.** Es una pausa suave, no un bloqueo (ADR-009). Un servicio en primer plano lee Usage Access cada segundo y cubre la app elegida con una ventana superpuesta. Ajustes, el marcador, los lanzadores y el teclado nunca se cubren. El uso de apps no sale del dispositivo. [Decisión](../../adr/009-focus-shield.md) · [Contador de uso](../../../android/app/src/main/kotlin/com/bimbi/app/UsageTracker.kt) · [Servicio](../../../android/app/src/main/kotlin/com/bimbi/app/FocusGuardService.kt) · [Pantalla de pausa](../../../android/app/src/main/kotlin/com/bimbi/app/ShieldOverlay.kt)
- **Pantallas.** Sleep se construyó a partir de la mesa de trabajo *Sleep report*, sin puntuación, rachas ni puntos. Focus y Focus shield siguen el lenguaje de Home. [Sleep](../../../lib/ui/sleep/widgets/sleep_screen.dart) · [Focus](../../../lib/ui/focus/widgets/focus_screen.dart) · [Focus shield](../../../lib/ui/focus/widgets/focus_shield_screen.dart)

## Verificación

| Entorno | Resultado observado |
|---|---|
| Comprobación integrada | `./scripts/check.sh` terminó con código 0. Formato y análisis limpios, 111 casos de Flutter (96 de la suite y 15 renders de revisión) y 2 casos de cambio de horario con `TZ=America/New_York`. Además, 13 casos del servidor, 13 de reglas en Firebase Emulator Suite y 19 pruebas JVM de Android. [Registro](checks.txt) |
| Pruebas unitarias | Se comprobaron estos casos:<br>• Una sesión restaurada tras terminar el proceso conserva el tiempo restante, la tarea y las ventanas.<br>• El anillo agrega o quita vueltas sin saltar al pasar por las 12.<br>• Cuentas: los datos de invitado se suben una sola vez, los cambios sin conexión esperan y otra cuenta no ve nada.<br>• El contador de uso maneja pantallas de una misma app, la medianoche y pausas faltantes. |
| Reglas en el emulador | El propietario verificado lee y escribe `sleep` y `focus`. Otras cuentas, usuarios anónimos y correos sin verificar reciben denegación. Se rechazan etapas de sueño, puntos, más de 16 h en cama y sesiones de más de 8 h. |
| Galaxy Tab A9 · Sleep | Se revisó en vertical y horizontal, vacío y con una noche de prueba. Se guardó y se eliminó desde la app, y el almacenamiento quedó vacío. El botón de guardar ya no queda bajo la barra de tareas de Samsung. [Sleep](tab-a9-sleep.png) · [Vacío y registro](tab-a9-sleep-empty-and-log.png) |
| Galaxy Tab A9 · Focus | Se inició una sesión real y Android recibió su hora de fin. Al terminar, la hora se borró y la sesión no se registró por durar menos de un minuto. |
| Galaxy Tab A9 · escudo | Se dieron los permisos por adb y se puso un límite de un minuto a Chrome. El servicio se inició en primer plano y Chrome quedó cubierto al llegar al límite. **Go home** y Atrás regresan al inicio, y el escudo volvió unos 0.7 s después de reabrir Chrome. Al revocar Usage Access, la ventana desapareció, el servicio se detuvo y quedó registrado `permission_revoked`. Al final se restauraron los permisos y las alarmas del propietario. [Pantalla de límite](tab-a9-daily-limit-overlay.png) |
| Emulador de 412 dp · Focus | Se escribió una duración de 2 minutos y se dividió en 1 + 1. Al iniciar, Android registró los dos sonidos y ambos sonaron: el reproductor de Bimbi inició y se liberó en cada uno. La pantalla mostró "Session complete. Nice work!". Sin permiso de alarmas exactas, Android los entregó hasta un minuto tarde. [Minutos y ventanas](phone-412-focus-typed-and-windows.png) · [Sesión completa](phone-412-focus-complete.png) |
| Emulador de 412 dp · escudo | Desde la pantalla Focus shield se buscó Chrome y se activó **Pause during Focus**. Se inició Focus y al abrir Chrome apareció "Paused during Focus · 2 min left". Al terminar la sesión, la pausa desapareció y el servicio se detuvo solo. Se restauraron los permisos del emulador. [Chrome en pausa](phone-412-shield-chrome.png) |
| Revisión visual | Renders a 390 × 844 y 1006 × 552 en claro, de noche y oscuro, aprobados por el propietario pantalla por pantalla. [Sleep](sleep-390-day-night.png) · [Sleep horizontal](sleep-1006-landscape.png) · [Focus](focus-390-ready-and-dark.png) · [Vueltas y ventanas](focus-390-turns-and-windows.png) · [Focus horizontal](focus-1006-landscape.png) · [Escudo](shield-390-access-and-ready.png) · [Límite diario](shield-390-daily-limit.png) · [Escudo horizontal](shield-1006-landscape.png) |

## Pendiente para el propietario

1. **Sincronización entre dispositivos.** Las reglas nuevas de Realtime Database se publicaron en `bimbi-26ae2` el 22 de noviembre de 2026, con autorización del propietario ([registro](checks.txt)). Falta comprobar en dos dispositivos con la misma cuenta verificada que una noche y una sesión se sincronizan.
2. **Sonidos en la tablet.** Confirmar que el sonido entre ventanas y el destello final se escuchan a tiempo.
3. **Escudo desde su pantalla en la tablet.** Dar los dos permisos desde la app y elegir una app para pausar durante Focus.
4. **Reinicio.** Reiniciar con un límite diario activo y confirmar que vuelve después de desbloquear.
5. **TalkBack.** Recorrer Sleep, Focus, la hoja de ventanas y Focus shield con TalkBack.

## Cómo repetir el recorrido

1. En **Sleep**, toca **Log last night**, ajusta las horas y guarda. Edita la noche desde *Your nights* o elimínala con **Delete night**.
2. En **Focus**, toca el número para escribir minutos exactos o gira el anillo. Pasar de 120 dibuja una segunda capa. Toca **Split into windows**, ajusta las ventanas y guarda. Al iniciar, el centro muestra la ventana actual. Al final de cada ventana suena un aviso, y al terminar la sesión suena un destello.
3. Abre la tarjeta **Focus shield** y permite Usage Access y Display over other apps. Activa **Pause during Focus** en una app o toca **Daily limit** y escribe horas y minutos. Inicia Focus y abre esa app.

## APK debug

```sh
flutter build apk --debug --no-pub --dart-define-from-file=config/dev.json
apksigner verify build/review/bimbi-phase5-debug.apk
shasum -a 256 build/review/bimbi-phase5-debug.apk
```

Copia firmada en `build/review/bimbi-phase5-debug.apk`, SHA-256 `77b80f1b104376d17a8bd5a6ae4a8a2d36c25241825f8a4e09bc36298c391b37`. Es la versión instalada en la Galaxy Tab A9 al cerrar la fase. [APK de desarrollo](../../../build/review/bimbi-phase5-debug.apk)
