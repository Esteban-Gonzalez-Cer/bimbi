# Bimbi · Cómo se implementó y validó la Fase 5

La Fase 5 se trabajó el 22 de noviembre de 2026 en la rama `codex/phase5-sleep-focus`, a partir del cierre de la Fase 4 (`0cc2163`). La especificación pedía tres cosas:
- un diario de sueño autorreportado que sobreviva a reinicios y guarde cambios sin conexión;
- un temporizador de Focus que se recupere si Android termina la app;
- funciones de Usage Access opcionales.

Con el propietario se decidió además:
- guardar todo en el dispositivo y sincronizar solo las cuentas verificadas;
- no notificar el final de una sesión (en su lugar suena un sonido);
- rediseñar Sleep y Focus pantalla por pantalla, con su aprobación;
- construir un escudo que pausa apps elegidas, con límites diarios.

[Informe de cierre](REPORT.md) · [Registro de comandos](checks.txt) · [Plan aprobado](../../decisions/gates.md)

## 1. Planear con la especificación y verificar si bloquear apps era posible

Se revisó la sección de la Fase 5 de la especificación v0.4: sueño autorreportado, Focus con marcas de tiempo y Usage Access opcional. Se acordaron con el propietario el almacenamiento, el comportamiento al terminar una sesión y el método de diseño.

El propietario pidió bloquear apps durante Focus y poner un límite diario por app. Antes de planearlo se investigó qué permite Android:
- no existe una API pública para bloquear otras apps;
- desde Android 15 hay restricciones para abrir actividades y servicios desde segundo plano.

La única vía compatible con la especificación, que prohíbe los servicios de accesibilidad, es una "pausa suave". Un servicio en primer plano lee Usage Access y dibuja una ventana encima de la app elegida.

El propietario eligió construirla completa. Se registró como un cambio a la especificación en el ADR-009. [ADR-009](../../adr/009-focus-shield.md)

## 2. Estructura del código

Las piezas nuevas siguen la guía de arquitectura de Flutter que ya usaba Home: [Guía de Flutter](https://docs.flutter.dev/app-architecture/guide)

| Capa | Carpeta | Contenido |
|---|---|---|
| Dominio | `lib/domain/models/` | `SleepEntry`, `FocusRecord`, `ShieldApp` y `ShieldStatus`. |
| Datos | `lib/data/repositories/`, `lib/data/services/` | Colección local con cambios pendientes, sincronización con Realtime Database y adaptador del escudo nativo. |
| Interfaz | `lib/ui/sleep/`, `lib/ui/focus/`, `lib/ui/core/widgets/` | Modelos de vista con Riverpod y pantallas. |
| Android | `android/app/src/main/kotlin/com/bimbi/app/` | `UsageTracker`, `FocusGuard`, `FocusGuardService`, `ShieldOverlay` y `FocusChime`. |

Las versiones anteriores de Sleep y Focus en `lib/features/` se migraron y se eliminaron.

## 3. Guardar Focus para que sobreviva a que Android termine la app

`FocusSession` guarda el objetivo, la fase, el inicio del tramo actual, el tiempo acumulado, la tarea y las ventanas. `FocusController` escribe la sesión en `SharedPreferences` en cada cambio y la reconstruye al abrir la app. El tiempo restante siempre se calcula desde marcas de tiempo, nunca con una cuenta regresiva en memoria.

Al terminar, la sesión se guarda en el historial si duró al menos un minuto. Queda como *completed* si llegó al objetivo o *ended* si se terminó antes. [Sesión de Focus](../../../lib/ui/focus/view_models/focus_session.dart) · [Registro](../../../lib/domain/models/focus_record.dart)

## 4. Diario de sueño seguro ante el cambio de horario

`SleepEntry` guarda la hora de acostarse y de despertar como instantes, con la diferencia UTC del despertar. La clave es la fecha local en que se despertó, `yyyy-MM-dd`, como en el modelo `users/{uid}/sleep/{dateKey}` de la especificación.

`entryFromTimes` pone la hora de dormir en la noche anterior usando el calendario, no 24 horas. Así, la noche del cambio de horario de otoño en Nueva York reporta 9 h y la de primavera 7 h. Estas pruebas corren con `TZ=America/New_York` dentro de `scripts/check.sh`. [Modelo](../../../lib/domain/models/sleep_entry.dart) · [Pruebas de horario](../../../test/tz/sleep_dst_test.dart) · [Script](../../../scripts/check.sh)

Cuando se completa el reto de una alarma, `AlarmEngine.complete()` guarda la última hora de despertar con sus posposiciones. Flutter la lee para sugerir la hora en el diario y mostrar "Snoozes" en el reporte. [Motor de alarmas](../../../android/app/src/main/kotlin/com/bimbi/app/AlarmEngine.kt) · [Diario](../../../lib/ui/sleep/view_models/sleep_diary.dart)

## 5. Sincronizar con Realtime Database

`CollectionController` es una colección local genérica que usan el diario y el historial de Focus:
- cada cambio se guarda y queda pendiente hasta que la nube lo confirma;
- una eliminación de una cuenta sincronizada deja una marca hasta confirmarse.

`CollectionSync` sigue el patrón del perfil de la Fase 3:
- solo actúa con una cuenta verificada;
- la primera cuenta adopta los datos de invitado y otra cuenta empieza vacía;
- escucha `onValue`, conserva un cambio local más nuevo que aún no se envió y manda los pendientes al recuperar la conexión. [Colección local](../../../lib/data/repositories/local_collection.dart) · [Sincronización](../../../lib/data/repositories/collection_sync.dart)

Las reglas aceptan solo al propietario verificado. Para `sleep` exigen:
- una fecha válida como clave;
- despertar después de acostarse, con un máximo de 16 h en cama;
- `source == 'diary'` y una nota de hasta 280 caracteres;
- ningún otro campo, así que no se pueden guardar etapas ni puntuaciones.

Para `focus` permiten de 60 s a 8 h, el estado `completed` o `ended` y una etiqueta de hasta 40 caracteres. Se probaron en Firebase Emulator Suite. [Reglas](../../../firebase/database.rules.json) · [Pruebas de reglas](../../../firebase/emulator-tests/rules.test.cjs)

## 6. El escudo de Focus en Android

Las piezas del escudo:
- **`UsageTracker`.** Es puro y tiene pruebas JVM. Convierte los eventos `ACTIVITY_RESUMED` y `ACTIVITY_PAUSED` en minutos por app desde la medianoche y sabe qué app está al frente.
- **`GuardStore`.** Guarda en almacenamiento privado las apps elegidas, los límites y la hora en que termina la sesión de Focus.
- **`FocusGuardService`.** Es un servicio `specialUse` que solo corre cuando hay algo que aplicar. Lee los eventos cada segundo con la pantalla encendida y muestra o quita `ShieldOverlay`.
- **`ShieldOverlay`.** Es la pantalla de pausa, con el estilo de la pantalla de alarma. Su único botón, **Go home**, y el botón Atrás llevan al inicio.
- **Apps que nunca se cubren:** Bimbi, los lanzadores, Ajustes, el marcador y el teclado.

Si se revoca un permiso, el servicio se detiene y guarda el motivo, que Bimbi muestra. Al reiniciar, actualizar o cambiar la hora, `RestoreReceiver` lo vuelve a iniciar si hace falta.

[Contador de uso](../../../android/app/src/main/kotlin/com/bimbi/app/UsageTracker.kt) · [Reglas y permisos](../../../android/app/src/main/kotlin/com/bimbi/app/FocusGuard.kt) · [Servicio](../../../android/app/src/main/kotlin/com/bimbi/app/FocusGuardService.kt) · [Pantalla de pausa](../../../android/app/src/main/kotlin/com/bimbi/app/ShieldOverlay.kt) · [Manifiesto](../../../android/app/src/main/AndroidManifest.xml)

```kotlin
internal fun shieldFor(pkg: String?, rules: GuardRules, usage: Map<String, Long>, now: Long, exempt: (String) -> Boolean): Shield? {
    if (pkg == null || exempt(pkg)) return null
    if (rules.focusActive(now) && pkg in rules.focusApps) return Shield.Focus(requireNotNull(rules.focusUntil))
    val limit = rules.limits[pkg] ?: return null
    val used = usage[pkg] ?: 0L
    return if (used >= limit * 60_000L) Shield.Limit(used, limit) else null
}
```

Flutter informa a Android hasta qué hora se pausan las apps. Lo hace cada vez que una sesión inicia, se pausa, se reanuda o termina, incluso si la sesión se restauró tras terminar el proceso. [Enlace con el temporizador](../../../lib/ui/focus/view_models/focus_shield.dart) · [Adaptador](../../../lib/data/services/focus_guard_service.dart)

## 7. Sonidos al terminar una ventana y la sesión

Se generaron dos sonidos originales con síntesis, sin grabaciones ni licencias externas:
- `focus_window`, dos notas suaves al terminar una ventana;
- `focus_done`, un arpegio ascendente con destellos al terminar la sesión.

`FocusChime` los registra con `AlarmManager`, exactos si Bimbi tiene permiso de alarmas exactas, para que suenen aunque la app esté cerrada. Se cancelan al pausar o terminar y se restauran tras un reinicio. [Generador](../../../scripts/generate_focus_sounds.py) · [Sonidos](../../../android/app/src/main/kotlin/com/bimbi/app/FocusChime.kt)

## 8. Rediseño pantalla por pantalla, con aprobación del propietario

Cada pantalla se renderizó a 390 × 844 con datos de ejemplo, se instaló en la Galaxy Tab A9 en vertical y horizontal, y se mostró lado a lado en el navegador. Solo se pasó a la siguiente pantalla con la aprobación del propietario.

1. **Sleep report.** Se construyó a partir de la mesa de trabajo *Sleep report* de Brand Buddy. Se quitaron la puntuación, "Good sleep!", la racha y los puntos, porque la especificación no permite juicios médicos ni gamificación antes de la Fase 9. Su lugar lo ocupan:
   - un reloj de 12 horas con la noche dibujada;
   - las horas de acostarse y despertar;
   - las posposiciones de la alarma;
   - el uso del teléfono en cama, con Usage Access.

   En la tablet se corrigieron dos detalles: etiquetas a mitad de fila y el botón de guardar debajo de la barra de tareas de Samsung. [Pantalla](../../../lib/ui/sleep/widgets/sleep_screen.dart) · [Hoja de registro](../../../lib/ui/sleep/widgets/diary_sheet.dart)
2. **Focus.** La primera versión se aprobó con cambios. Se quitaron la tarjeta de duración y los totales del día. El anillo ahora agrega una capa por cada vuelta de 2 h, hasta 8 h, y la quita al regresar. Al tocar el número se escriben minutos exactos. Las líneas de estado usan la tipografía serif. Se agregaron las ventanas y los sonidos. Con ventanas, el anillo se bloquea para no borrarlas sin querer. Una prueba encontró un error que se corrigió: al regresar el anillo desde pocos minutos saltaba a casi una vuelta completa. [Pantalla](../../../lib/ui/focus/widgets/focus_screen.dart) · [Anillo](../../../lib/ui/focus/widgets/focus_dial.dart)
3. **Focus shield.** Tiene una explicación honesta, la lista de permisos de Android y la lista de apps con búsqueda. Cada app tiene **Pause during Focus** y un límite diario. A pedido del propietario, el límite se escribe libremente en dos campos, horas y minutos, en lugar de elegir opciones fijas. [Pantalla](../../../lib/ui/focus/widgets/focus_shield_screen.dart)

## 9. Pruebas

| Tipo | Qué cubre |
|---|---|
| Unitarias de Dart | Sesión restaurada tras terminar el proceso, historial registrado una vez, minutos exactos y pasos del anillo, vueltas, ventanas, diario por día, semana, sugerencia de la alarma, colección local y sincronización con una nube falsa. |
| Cambio de horario | Noches de otoño y primavera con `TZ=America/New_York`. |
| Widgets | Pestañas a 360, 412, 700 y 900 dp con texto al 100, 130 y 200 %; Focus con minutos escritos y ventanas; el escudo pausando una app y guardando 1 h 15 min. |
| JVM de Android | Contador de uso (pantallas de una misma app, medianoche, pausas faltantes) y reglas del escudo. |
| Reglas | Propietario, otras cuentas, anónimos, sin verificar y filas inválidas. |
| Dispositivos | Tablet: Sleep, Focus, escudo por límite diario y revocación de permisos. Emulador: sonidos y escudo durante Focus desde la pantalla. |

```sh
./scripts/check.sh
```

## 10. Cuidado de la tablet del propietario

Cada prueba en la tablet terminó dejándola como estaba:
- se restauraron la rotación, Usage Access y la superposición;
- se eliminaron la noche y las reglas de prueba;
- se reabrió Bimbi para volver a programar las alarmas del propietario después de detener la app.

Cuando el propietario estaba usando Focus en la tablet, la prueba de sonidos se hizo en el emulador para no cambiar su sesión. Las capturas de la tablet que muestran sus apps instaladas no se guardaron como evidencia.

## 11. Pendientes

Faltan cinco pasos:
- probar la sincronización entre dos dispositivos (las reglas ya se publicaron en el proyecto de desarrollo);
- escuchar los sonidos en la tablet;
- usar el escudo desde su pantalla en la tablet;
- reiniciar con un límite activo;
- hacer un recorrido con TalkBack.

[Pendientes del informe](REPORT.md#pendiente-para-el-propietario) · [Limitaciones](../../LIMITATIONS.md)
