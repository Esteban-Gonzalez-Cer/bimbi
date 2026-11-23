# Bimbi · Fase 7 · Notificaciones y planes

**Fecha de verificación** · 22 de noviembre de 2026, Ciudad de México.

**Rama** · `codex/phase7-notifications-plans`, desde `48328c3`. Incluye la Fase 6 (Running) y el cierre de la Fase 5.

**Resultado** · CONDITIONAL PASS.
- Las campañas de Firebase Console al tema `bimbi_tips` llegaron a la Galaxy Tab A9 en los tres estados: con Bimbi abierta, en segundo plano y después de cerrarla desde Recientes.
- Los planes Free, Plus y Premium son pases de prueba de 30 días. Solo el servidor los activa, después de verificar el pago con Stripe en modo de prueba.
- El propietario confirmó en la tablet:
  - pago cancelado y rechazado;
  - pago exitoso;
  - Restore purchases;
  - las ventajas de Plus.
- Las pantallas Running, Plans y Notifications se aprobaron una por una.
- Quedan cuatro comprobaciones del propietario, listadas al final.

## Implementación

- **Running (pasada de interfaz de la Fase 6).** Encabezado con fecha, tarjeta de sesión con mapa, métricas y acciones del mismo ancho, e historial con filas redondeadas. En tablets horizontales se muestra en dos columnas.
  - Se quitó la tarjeta con el nombre "Bosque de Chapultepec". El marcador sigue en el mapa.
  - El controlador, el almacenamiento y la sincronización no cambiaron.
  - [Running](../../../lib/features/running/presentation/running_page.dart)
- **Planes en el servidor.** Cuando `verifyPaymentIntent` ve `succeeded`, una transacción de Realtime Database con el Admin SDK escribe `users/{uid}/entitlements`. Antes se comprueban dueño, monto, `mxn` y `livemode=false`. Después se escribe el recibo `users/{uid}/payments/{paymentIntentId}`. `applyGrant` es puro y tiene pruebas:
  - el mismo plan activo se extiende desde su vencimiento;
  - una mejora o un pase vencido empieza hoy;
  - un plan menor nunca reemplaza uno mayor activo;
  - `grants` evita sumar días dos veces por el mismo pago.

  [Reglas de pago](../../../payment_demo/server/src/payments.ts) · [Función](../../../payment_demo/server/src/index.ts) · [ADR-005](../../adr/005-stripe-trusted-endpoint.md)
- **Reglas.** El dueño verificado puede leer `entitlements` y `payments`, pero ningún cliente puede escribirlos. `preferences/notificationTopics` solo acepta los booleanos `tips` y `updates`. [Reglas](../../../firebase/database.rules.json)
- **Cliente.** `entitlementProvider` lee el plan del servidor sin poder escribirlo. `planTierProvider` trata un pase vencido como Free. Las ventajas dependen solo de ese valor:
  - Plus: tres colores del buddy (Rose, Peach y Violet) y dos tonos de alarma (Sparkle Rise y Lullaby Glow);
  - Premium: el tema Sunrise y una insignia.

  Al vencer el pase, el color y el tema vuelven a los de siempre. Las alarmas con tonos de Plus se guardan con Dawn Chime, pero solo después de cargar el plan. [Modelo](../../../lib/domain/models/plan.dart) · [Repositorio](../../../lib/data/repositories/entitlement_repository.dart) · [Ventajas](../../../lib/ui/plans/view_models/plan_perks.dart)
- **Pantalla Plans.** Contiene:
  - el plan actual con su vencimiento;
  - el aviso de modo de prueba;
  - tres tarjetas de plan con su acción (Get, Renew 30 days o Upgrade to Premium);
  - Restore purchases;
  - los recibos de prueba.

  La tarjeta la captura la PaymentSheet de Stripe; Bimbi nunca la ve. [Plans](../../../lib/ui/plans/widgets/plans_screen.dart) · [Pagos](../../../lib/features/payments/payment_adapter.dart)
- **Notificaciones.**
  - Hay dos temas opcionales, `bimbi_tips` y `bimbi_updates`, cada uno con su canal de Android del mismo nombre. El tema de prueba `bimbi_phase1` se da de baja una vez.
  - Activar un tema pide primero el permiso de Android. La elección se guarda en el dispositivo y, con cuenta verificada, también en la nube.
  - Un mensaje con la app abierta se muestra como un banner sobre cualquier pantalla. Tocar una notificación abre la pantalla de `destination`, siempre dentro de una lista permitida.

  [ADR-010](../../adr/010-notification-topics.md) · [Modelos de vista](../../../lib/ui/notifications/view_models/notifications.dart) · [Pantalla](../../../lib/ui/notifications/widgets/notifications_screen.dart) · [Banner](../../../lib/ui/notifications/widgets/message_banner.dart)

## Verificación

| Entorno | Resultado observado |
|---|---|
| Comprobación integrada | `./scripts/check.sh` terminó con código 0, con formato y análisis limpios. Corrieron 146 casos de Flutter (2 omitidos) y 2 de cambio de horario con `TZ=America/New_York`. Además, 19 casos del servidor, 21 de reglas en Firebase Emulator Suite y 19 pruebas JVM de Android. [Registro](checks.txt) |
| Servidor | Se comprobaron estos casos:<br>• alta de Plus y Premium;<br>• extensión del mismo plan;<br>• mejora de Plus a Premium;<br>• rechazo de Plus con Premium activo (`higher_plan_active`);<br>• una segunda verificación no suma días;<br>• rechazo de modo en vivo y de monto incorrecto. |
| Reglas en el emulador | Un cliente no puede escribir `entitlements` ni `payments`. Solo el dueño verificado los lee. `notificationTopics` rechaza campos extra y valores que no sean booleanos. |
| Flutter | Se comprobaron estos casos:<br>• plan vencido como Free;<br>• colores y tonos bloqueados sin pase;<br>• baja del tema anterior;<br>• permiso denegado;<br>• sincronización entre cuentas;<br>• lista permitida de pantallas;<br>• el banner sobre una pantalla abierta (Notifications) y Open regresando a las pestañas. |
| Publicación | Las reglas combinadas (Fases 5, 6 y 7) y `paymentApi` se publicaron en `bimbi-26ae2` con autorización del propietario. En vivo, sin cuenta, `paymentApi` responde 405 a GET y 401 sin token o con token inválido. [Registro](checks.txt) |
| Galaxy Tab A9 · FCM con la app abierta | La primera prueba del propietario no mostró nada. El registro de Android tenía `FLTFireMsgReceiver: broadcast received` a las 22:10 y 22:14, así que el mensaje sí llegó. Bimbi estaba en la pantalla Notifications, que tapaba el banner. Se movió el banner encima de todas las pantallas y el propietario confirmó que aparece. |
| Galaxy Tab A9 · FCM en segundo plano y cerrada | El propietario envió la campaña con Bimbi en segundo plano y después de cerrarla desde Recientes. En ambos casos llegó la notificación y al tocarla se abrió Bimbi. |
| Galaxy Tab A9 · Stripe | El propietario confirmó:<br>• al cancelar, el plan siguió en Free;<br>• la tarjeta de prueba `4000 0000 0000 0002` fue rechazada sin cambio de plan;<br>• la tarjeta `4242 4242 4242 4242` activó Plus con vencimiento y recibo;<br>• Restore purchases no movió el vencimiento;<br>• se desbloquearon las ventajas de Plus. |
| Revisión visual | Renders a 390 × 844 y 1006 × 552, aprobados por el propietario pantalla por pantalla. [Running](running-390-states.png) · [Plans](plans-390-free-plus-premium.png) · [Plans horizontal](plans-1006-landscape.png) · [Notifications y banner](notifications-390-and-banner.png) |
| Capturas de la tablet | [Running](tab-a9-running.png) · [Plans](tab-a9-plans.png) · [Notifications](tab-a9-notifications.png) · [Ventajas bloqueadas](tab-a9-appearance-locked-perks.png) |

## Pendiente para el propietario

1. **Force-stop.** Detener Bimbi desde Ajustes › Apps, enviar una campaña y confirmar que no llega nada hasta abrir la app. Es el comportamiento esperado de Android y ya está documentado ([limitaciones](../../LIMITATIONS.md)).
2. **Premium en la tablet.** Pagar la mejora a Premium y confirmar el tema Sunrise y la insignia.
3. **Dos dispositivos.** Con la misma cuenta verificada, confirmar que el segundo dispositivo:
   - sigue los mismos temas;
   - muestra el mismo plan.

   Esto también cubre la sincronización de carreras pendiente de la Fase 6.
4. **TalkBack.** Recorrer Running, Plans, Notifications y el banner.

## Cómo repetir el recorrido

1. En **Profile › Notifications**, activa **Tips** y permite las notificaciones.
2. En Firebase Console, crea una campaña al tema `bimbi_tips`. En las opciones de Android usa el canal `bimbi_tips`. Puedes agregar el dato `destination` con `sleep`, `focus`, `plans` u otra pantalla permitida.
3. Envía la campaña con Bimbi abierta (aparece el banner), en segundo plano y cerrada desde Recientes (aparece una notificación).
4. En **Profile › Plans**, toca **Get Plus** y paga con una tarjeta de prueba de Stripe. Después toca **Restore purchases** y revisa **Test receipts**.

## APK debug

```sh
flutter build apk --debug --no-pub --dart-define-from-file=config/dev.json
apksigner verify build/review/bimbi-phase7-debug.apk
shasum -a 256 build/review/bimbi-phase7-debug.apk
```

Copia firmada en `build/review/bimbi-phase7-debug.apk`, SHA-256 `37cc040424cbb51cd7be3554a5b013dbf5fe07aae2c4ed5d1028ba0390b5e95a`. Es la versión instalada en la Galaxy Tab A9 al cerrar la fase. [APK de desarrollo](../../../build/review/bimbi-phase7-debug.apk)
