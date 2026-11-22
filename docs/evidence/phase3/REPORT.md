# Bimbi · Evidencia de la Fase 3

**Fecha** · 22 de noviembre de 2026, Ciudad de México.

**Resultado** · PASS. Se comprobaron la sincronización entre dispositivos, la autorización de avatar y la restauración de la foto sin conexión.

**Base** · Fase 2 guardada en `7ebc51e`. Implementación local en `codex/phase3-firebase`. Proyecto de desarrollo `bimbi-26ae2`. [Decisiones de fases](../../decisions/gates.md)

## Qué se implementó

- **Cuenta.** Se separó el arranque de Firebase del interruptor de herramientas de desarrollo. Se conservaron correo, Google y GitHub, con refresco de sesión al volver a Bimbi y desde **Refresh status**. La alarma sigue pasando por su adaptador Android y funciona con Firebase sin configurar. [Arranque](../../../lib/main.dart) · [Adaptador de Auth](../../../lib/features/auth/auth_adapter.dart)
- **Nombre.** Un proveedor de Riverpod sincroniza el nombre del propietario verificado y espera la confirmación de Realtime Database antes de indicar que quedó guardado. El nombre de invitado, el tema y el color de la mascota se guardan en el dispositivo. [Controlador](../../../lib/features/profile/application/cloud_profile.dart) · [Reglas de datos](../../../firebase/database.rules.json)
- **Foto.** Una función de creación de cuenta registra el proveedor original como un atributo que sólo escribe el servidor. Storage exige ese atributo, contraseña activa y correo verificado para editar la foto. Se usa el selector de Android y se normaliza la imagen a JPEG de hasta 512 px y 256 KiB. [Función de identidad](../../../payment_demo/server/src/identity.ts) · [Reglas de archivos](../../../firebase/storage.rules)
- **Sin conexión.** Se guarda una copia de la foto en el almacenamiento privado por proyecto de Firebase y cuenta. Se reutiliza tras un reinicio con la misma sesión, vence a los siete días desde la última carga y se retira al salir o cambiar de cuenta. [Repositorio](../../../lib/features/profile/infrastructure/firebase_profile.dart) · [Caché](../../../lib/features/profile/infrastructure/file_profile_cache.dart)

## Resultados

| Entorno | Resultado comprobado |
|---|---|
| Flutter y código del servidor | Formato y análisis limpios. 72 pruebas de Flutter y 13 pruebas del servidor. |
| Firebase Emulator Suite | 11 pruebas aprobadas. Dos clientes reciben el cambio de nombre. Las cuentas ajenas, anónimas o sin verificar reciben denegación. Se comprobó el atributo de origen con eventos de creación y el rechazo de edición a una cuenta de origen OAuth que usa contraseña. |
| Teléfonos Android de 360 y 412 dp | La prueba de integración recorrió las cinco pestañas en ambos anchos. En una compilación dirigida al emulador de Firebase, el teléfono de 412 dp leyó el nombre y la foto, mostró la autorización de edición y confirmó un cambio de nombre. |
| Proyecto de desarrollo | Se publicaron las reglas de Realtime Database y Storage y la función `assignBimbiAuthOrigin` en `us-central1`. |
| Galaxy Tab A9 SM-X115, Android 16 | El propietario confirmó el registro sin verificar, el reenvío y la carga de la foto tras verificar el correo. Los metadatos del proyecto de desarrollo confirmaron el origen por contraseña y el JPEG privado. |
| Tablet y teléfono de 412 dp con Firebase de desarrollo | La tablet mostró **Name synced**. El propietario inició sesión en el teléfono con la misma cuenta y vio el nombre y la foto que guardó en la tablet. También confirmó que recibió el correo de recuperación y pudo volver a entrar con la contraseña nueva. |
| Cambio de cuenta en la Galaxy Tab A9 | El propietario entró con Google y después con GitHub. En ambos vio el proveedor correspondiente y su foto de cuenta, que sustituyó a la foto personalizada anterior. **Choose photo** permaneció oculto en las dos sesiones. |
| Galaxy Tab A9 en modo avión | Con el Wi-Fi apagado, Bimbi arrancó en un proceso nuevo, restauró la sesión y mostró la foto guardada de esa cuenta. La pantalla **Alarms** se pudo abrir en el mismo estado. Al terminar se restauró la conexión. |
| Invitado en el teléfono emulado de 360 dp | En modo avión y sin Wi-Fi, Android registró una alarma desde **Alarms** y se comprobó que su registro desapareció al cancelarla en Bimbi. La hora programada quedó fuera de la ventana de prueba. |
| Diseño en la Galaxy Tab A9 | **Profile** y **Appearance** se abrieron en vertical y en horizontal. Atrás de Android regresó a la lista de Profile en vertical. Se restauró la orientación original. |
| CI | Comprobaciones locales ejecutadas. El flujo hospedado queda preparado para el repositorio remoto. |

[Comandos y resultados](checks.txt) · [Configuración reproducible](../../SETUP.md#phase-3-profile-and-emulator-verification)

## Cómo repetir la prueba entre dispositivos

1. Instala el APK en la tablet y en un teléfono emulado. En la tablet, registra una cuenta de correo de desarrollo nueva en **Profile → Account**. Comprueba **Email not verified**, usa **Resend verification**, abre el enlace de correo y toca **Refresh status** al volver a Bimbi.
2. Elige una imagen de prueba en **Choose photo**. Guarda un nombre en **Appearance** y espera **Name synced**. En el teléfono, inicia sesión con la misma cuenta y abre **Profile**. Debe mostrar los dos valores.
3. En la tablet, conserva la sesión, activa el modo avión y apaga el Wi-Fi. Sal de Bimbi, termina su proceso en segundo plano y vuelve a abrirlo. **Profile** debe mostrar la foto que esa cuenta descargó previamente. Restaura la conexión al terminar.
4. Cierra sesión y prueba Google y GitHub. Confirma que cada sesión muestra su proveedor y su propia foto, o la mascota cuando el proveedor no tiene foto. Comprueba que la edición de foto personalizada está reservada para la cuenta autorizada por contraseña.

## APK de desarrollo

El APK se compiló con `flutter build apk --debug --no-pub --dart-define-from-file=config/dev.json`. Se verificó la firma con `apksigner` y se instaló como actualización en la Galaxy Tab A9 y en el teléfono emulado de 412 dp. La copia de entrega está en `build/review/bimbi-phase3-debug.apk`. SHA-256 `608759abcd04e8028c853130f299e538c3ac7513f9d9978542b28ddfcd86ad9e`.

El primer intento en la tablet mostró un aviso de falta de conexión aunque la tablet tenía internet. Bimbi dependía de la señal de conexión de Realtime Database para decidir si podía intentar guardar. La versión de entrega inicia la escritura y espera hasta 15 segundos a que Firebase la confirme. Si se agota el plazo, retira las escrituras pendientes del cliente y conserva el último valor confirmado. El guardado y la lectura en el segundo dispositivo se comprobaron con este cambio.

Para repetir el registro de correo en el proyecto de desarrollo, el propietario autorizó borrar una sola cuenta de prueba por contraseña. Se comprobó que no tenía un perfil en Realtime Database y que las otras cuentas permanecieron después del borrado.
