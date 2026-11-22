# Bimbi · Cómo se implementó y validó la Fase 3

El trabajo se cerró el 22 de noviembre de 2026 con el commit `7921040` de la rama `codex/phase3-firebase`. Esta guía sigue el trabajo desde la preparación del proyecto hasta la instalación del APK. El resultado fue un perfil que sincroniza el nombre y la foto entre dispositivos, conserva una copia privada de la foto para abrirla sin conexión y mantiene la alarma disponible como invitado. [Informe de cierre](REPORT.md) · [Registro de comandos y resultados](checks.txt)

## 1. Guardar el punto de partida y preparar los dos entornos

Se revisó el cierre visual de la Fase 2, se guardó en el commit `7ebc51e` y se abrió `codex/phase3-firebase` en el mismo directorio del proyecto. Se mantuvieron Flutter 3.47.5, el paquete Android `com.bimbi.app`, el proyecto Firebase de desarrollo `bimbi-26ae2` y los perfiles de teléfono de 360 y 412 dp. Para las pruebas repetibles se usó el proyecto aislado `demo-bimbi` de Firebase Emulator Suite. [Implementación de la Fase 2](../phase2/IMPLEMENTACION_FASE_2.md) · [Versión de Flutter](../../../.fvmrc) · [Configuración de Firebase](../../../firebase.json)

En `AppConfig` se separó `PHASE1_HARNESS`, que controla **Developer tools**, de la configuración que inicia Firebase. `main.dart` inicializa Firebase con los valores locales de `config/dev.json` en la compilación de desarrollo y publica el resultado en `firebaseReadyProvider`. Si la inicialización falla, se abre el armazón de la app y la alarma sigue usando Android. [Configuración de la app](../../../lib/core/config.dart) · [Arranque y proveedores](../../../lib/main.dart)

Con `FIREBASE_EMULATORS=true` en modo debug, la app dirige Auth, Realtime Database y Storage a los puertos 9099, 9000 y 9199 de `10.0.2.2`, la dirección del equipo anfitrión vista desde el emulador Android. La función de identidad recibe el evento de Auth dentro de Firebase Emulator Suite. El manifiesto de depuración referencia una configuración de red que permite HTTP únicamente en las direcciones locales declaradas. FCM queda desactivado en ese modo. [Manifiesto de depuración](../../../android/app/src/debug/AndroidManifest.xml) · [Política de red local](../../../android/app/src/debug/res/xml/firebase_emulator_network.xml) · [Mensajería](../../../lib/features/notifications/messaging.dart)

## 2. Llevar el flujo de cuenta a Profile

Se reutilizó `FirebaseAuthAdapter`. El adaptador crea cuentas por correo y contraseña, obtiene una credencial de Google y abre GitHub con `GithubAuthProvider`. `sessionProvider` observa `auth.userChanges()` para que Profile reaccione al inicio, el cierre y la restauración de la sesión. Al entrar de nuevo en Bimbi o pulsar **Refresh status**, el adaptador vuelve a leer el usuario y fuerza la renovación del token. Así, tanto Flutter como las reglas pueden usar el estado de verificación actualizado después de abrir el enlace de correo. [Adaptador de Auth](../../../lib/features/auth/auth_adapter.dart) · [Ciclo de vida de la app](../../../lib/app/shell/adaptive_shell.dart)

`AccountSection` muestra si está restaurando la cuenta, si falta la configuración de Firebase o si hubo un error de conexión. Con una sesión abierta, presenta el proveedor, **Email verified** o **Email not verified**, y las acciones de refresco y salida. El alta envía el primer correo, **Resend verification** lo reenvía y **Forgot password?** solicita la recuperación desde el formulario de acceso. `OperationController` evita operaciones dobles y convierte los errores del SDK en mensajes breves sin enlaces ni datos de sesión. [Vista Account](../../../lib/features/profile/presentation/profile_page.dart) · [Manejo de operaciones](../../../lib/core/operation.dart)

## 3. Conectar Appearance con Realtime Database

Se definieron `ProfileRepository` y `ProfileCache` para que la interfaz dependa del controlador de Riverpod y éste pueda probarse con repositorios de prueba. `FirebaseProfileRepository` escribe en `users/{uid}/profile/displayName` y escucha esa misma ruta con `onValue`. Cuando Firebase acepta un cambio, los otros dispositivos con la misma cuenta reciben el valor. Si dos dispositivos guardan, queda la última escritura aceptada. [Contratos del perfil](../../../lib/features/profile/application/profile_data.dart) · [Controlador](../../../lib/features/profile/application/cloud_profile.dart) · [Repositorio Firebase](../../../lib/features/profile/infrastructure/firebase_profile.dart)

Se validó que el nombre tenga de 1 a 40 caracteres. Flutter recorta los espacios de los extremos y rechaza los saltos de línea. Las reglas permiten leer el perfil y escribir el nombre al propietario con correo verificado. En el servidor, el valor debe existir, ser texto, respetar la longitud y carecer de espacios ASCII iniciales o finales. Los demás campos de perfil quedan fuera del permiso de escritura. El nombre de invitado, el tema y el color de la mascota usan `SharedPreferences` en cada dispositivo. [Reglas de Realtime Database](../../../firebase/database.rules.json) · [Vista Appearance](../../../lib/features/profile/presentation/profile_page.dart) · [Preferencias del dispositivo](../../../lib/app/preferences.dart)

La transacción del repositorio aplica el cambio cuando lo confirma Firebase. Si la transacción termina sin confirmar, propaga un error al controlador. [Implementación de `saveName`](../../../lib/features/profile/infrastructure/firebase_profile.dart)

```dart
Future<void> saveName(String uid, String name) async {
  final result = await _name(uid)
      .runTransaction((_) => Transaction.success(name), applyLocally: false);
  if (!result.committed) {
    throw const CapabilityFailure('aborted', 'Name change was not saved.');
  }
}
```

El editor mantiene el texto ingresado mientras el guardado está pendiente. La suscripción actualiza el nombre confirmado y la interfaz muestra **Name synced** cuando el servidor confirma la transacción. `visibleProfileNameProvider` comparte el resultado entre **Profile** y el saludo de **Alarms**. [Estado y acciones de perfil](../../../lib/features/profile/application/cloud_profile.dart) · [Modelo del inicio](../../../lib/ui/home/view_models/home_view_model.dart)

## 4. Autorizar la foto por el origen de la cuenta

Se creó `assignBimbiAuthOrigin`, una función TypeScript de primera generación que se ejecuta al crear una cuenta en Firebase Auth. `originAtCreation` toma los proveedores del evento original y asigna `password`, `google.com`, `github.com` o `unknown`. `recordAuthOrigin` escribe ese dato en el atributo `bimbiAuthOrigin` del token mediante Firebase Admin. Si un evento se procesa de nuevo, conserva la marca ya registrada y los demás atributos de la cuenta. La función se exporta desde el servidor con el que ya contaba el proyecto y se ejecuta en `us-central1`, con cero instancias mínimas y un máximo de una. [Función de identidad](../../../payment_demo/server/src/identity.ts) · [Exportación](../../../payment_demo/server/src/index.ts)

Storage aplica tres requisitos para crear, sustituir o borrar la foto. La cuenta debe ser la propietaria con correo verificado, su origen debe estar acreditado como `password` y su sesión actual debe usar contraseña. Por ejemplo, al vincular una contraseña a una cuenta creada con Google, sólo cambia el método con el que puede entrar. La marca de origen sigue siendo `google.com`. Una cuenta anterior sin origen acreditado puede sincronizar su nombre tras verificar el correo y tiene desactivada la edición de la foto. [Reglas de Storage](../../../firebase/storage.rules) · [Pruebas de la marca de origen](../../../payment_demo/server/test/identity.test.cjs)

```text
function canEditAvatar() {
  return verifiedOwner() &&
    request.auth.token.bimbiAuthOrigin == 'password' &&
    request.auth.token.firebase.sign_in_provider == 'password';
}
```

El controlador lee esos atributos del token para mostrar **Choose photo** y **Remove photo** sólo cuando corresponde. Las reglas de Storage aplican la misma autorización al recibir cada solicitud. [Controlador de permisos](../../../lib/features/profile/application/cloud_profile.dart) · [Controles de foto](../../../lib/features/profile/presentation/profile_page.dart)

## 5. Seleccionar, convertir y guardar la foto

**Choose photo** usa `ImagePicker` para seleccionar una imagen en Android con `requestFullMetadata: false`. `normalizeAvatar` valida el formato y las dimensiones antes de decodificar, corrige la orientación y reduce el lado mayor a 512 px como máximo. Dibuja el resultado en un lienzo RGB nuevo para descartar los metadatos originales, incluida cualquier ubicación, y ajusta la compresión hasta obtener un JPEG de hasta 256 KiB. Los límites de entrada del repositorio son 12 MiB para el archivo seleccionado y 24 megapíxeles para la imagen. [Selector y conversión JPEG](../../../lib/features/profile/infrastructure/firebase_profile.dart) · [Dependencias declaradas](../../../pubspec.yaml) · [Versiones resueltas](../../../pubspec.lock)

El resultado se sube a `users/{uid}/avatar.jpg` con `putData` y el tipo `image/jpeg`. Storage valida el propietario, la autorización, el tamaño y el tipo declarado. La app descarga la foto con `getData` del SDK autenticado y vuelve a normalizar los datos recibidos. Para una sesión de Google o GitHub, el repositorio intenta cargar la foto disponible del proveedor por HTTPS con un límite de tamaño. `ProfilePicture` muestra la mascota cuando falta una foto utilizable y sólo presenta la imagen asociada al UID de la sesión actual. El mismo widget se usa en el resumen de **Profile** y en **Alarms**. [Operaciones de archivos](../../../lib/features/profile/infrastructure/firebase_profile.dart) · [Reglas](../../../firebase/storage.rules) · [Widget del avatar](../../../lib/features/profile/presentation/profile_picture.dart) · [Encabezado de Alarms](../../../lib/ui/home/widgets/home_screen.dart)

## 6. Restaurar la foto sin conexión y aislar las sesiones

`FileProfileCache` guarda el último nombre confirmado y la foto en el directorio privado de la app. La ruta se separa por proyecto Firebase y por UID, ambos convertidos a hashes SHA-256. Las lecturas, escrituras y limpiezas se procesan en orden. Una escritura termina con el renombrado de un archivo temporal, de modo que la siguiente lectura ve la copia completa. La antigüedad de la foto se calcula al abrir el archivo, desde su última escritura correcta. Si han transcurrido siete días, se elimina en esa lectura. [Implementación de la caché](../../../lib/features/profile/infrastructure/file_profile_cache.dart)

Cuando Firebase Auth restaura una sesión verificada, `CloudProfileController` carga la caché correspondiente y luego abre las suscripciones. Al volver a **Profile**, reanudar la app o recuperar la conexión, solicita la foto actual. Al cerrar sesión, cambiar de cuenta o retirar la foto, limpia la copia correspondiente. Los identificadores de la sesión y de cada solicitud permiten descartar una respuesta antigua aunque la descarga termine después del cambio de cuenta. La alarma sigue comunicándose con `AlarmManager` por el adaptador Android. [Ciclo del perfil](../../../lib/features/profile/application/cloud_profile.dart) · [Activación desde la navegación](../../../lib/app/shell/adaptive_shell.dart) · [Alarma nativa](../../../android/app/src/main/kotlin/com/bimbi/app/AlarmEngine.kt)

## 7. Probar los componentes antes del despliegue

Se añadieron pruebas de Flutter para la conversión del JPEG, la expiración y limpieza de la caché, el nombre pendiente de confirmación y la respuesta de una foto que llega tras cambiar de cuenta. Las pruebas TypeScript verifican que se use el origen del evento de creación y que los atributos existentes se conserven al repetirlo. [Pruebas del perfil](../../../test/unit/profile_test.dart) · [Pruebas del servidor](../../../payment_demo/server/test/identity.test.cjs)

En `demo-bimbi` se comprobó que dos clientes de la misma cuenta ven el cambio de nombre y que las reglas rechazan lecturas y escrituras ajenas, anónimas y sin verificar. También se probaron campos inesperados, límites de la imagen y el caso de una cuenta OAuth que presenta una sesión por contraseña. Una prueba aparte dispara eventos de creación en el emulador de Auth y verifica la marca que asigna la función. [Pruebas de reglas](../../../firebase/emulator-tests/rules.test.cjs) · [Prueba de eventos de Auth](../../../firebase/emulator-tests/identity.test.cjs)

Para probar el flujo desde Android se preparó una cuenta verificada y un JPEG sintético en los emuladores. Con el teléfono de 412 dp se comprobó que la app leyera el nombre y la imagen, mostrara el permiso de edición y sincronizara un cambio. Durante esa prueba se detectó un problema al salir de **Appearance** con sesión abierta. El controlador del campo de invitado podía inicializarse por primera vez durante `dispose()` y consultar Riverpod mientras salía la vista. Se llevó la inicialización a `initState()` y se repitió el recorrido de entrada y salida. [Preparación de datos de prueba](../../../firebase/emulator-tests/seed-profile.cjs) · [Prueba Android con Firebase emulado](../../../integration_test/profile_emulator_test.dart) · [Ciclo de los campos de Appearance](../../../lib/features/profile/presentation/profile_page.dart)

Desde la raíz del proyecto, con JDK 21, Node 22 y Flutter 3.47.5, estas comprobaciones se pueden repetir localmente. [Preparación y ejecución](../../SETUP.md#phase-3-profile-and-emulator-verification) · [Script de comprobación](../../../scripts/check.sh)

```sh
npm ci --prefix payment_demo/server
npm ci --prefix firebase/emulator-tests
./scripts/check.sh
```

## 8. Publicar sólo las reglas y la función de identidad

Tras pasar las pruebas de emuladores, se desplegaron las reglas de Realtime Database y Storage y la función `assignBimbiAuthOrigin` en el proyecto de desarrollo. El filtro de Firebase CLI identifica la función dentro del grupo `bimbi-phase1`. Para validar el evento de creación con una cuenta real de prueba, el propietario autorizó eliminar una sola cuenta antigua de correo y contraseña. Se comprobó que esa cuenta carecía de perfil en Realtime Database y que las otras cuentas siguieron disponibles. La cuenta recreada recibió la marca de origen por contraseña. [Registro del despliegue](checks.txt) · [Alcance de la configuración](../../SETUP.md#phase-3-profile-and-emulator-verification)

```sh
./scripts/firebase.sh deploy \
  --only database,storage,functions:bimbi-phase1:assignBimbiAuthOrigin \
  --project bimbi-26ae2
```

## 9. Corregir el guardado del nombre en la tablet

La primera prueba física permitió verificar el correo y cargar la foto. Al guardar el nombre, Bimbi mostró el aviso de falta de internet aunque la tablet tenía conexión. El controlador usaba `.info/connected` de Realtime Database para decidir si podía iniciar la escritura. Se cambió el flujo para intentar la transacción y esperar hasta 15 segundos a que Firebase la confirme. La señal de conexión se conserva para indicar si la app está guardando o esperando la conexión. [Conexión del repositorio](../../../lib/features/profile/infrastructure/firebase_profile.dart) · [Controlador `saveName`](../../../lib/features/profile/application/cloud_profile.dart)

Si se agota el plazo, la app retira las escrituras aún pendientes en el cliente y muestra **Firebase could not confirm the name. Try again.** El perfil conserva el último valor recibido. Se instaló la versión corregida en la tablet y en el teléfono emulado de 412 dp. La tablet mostró **Name synced** y el propietario confirmó que la otra instalación mostraba el nombre y la foto de la misma cuenta. [Prueba entre dispositivos](REPORT.md#resultados)

## 10. Comprobar el APK en Android

| Comprobación | Resultado observado |
|---|---|
| Correo de prueba | En la Galaxy Tab A9 se registró la cuenta, se observó **Email not verified**, se reenvió el correo y, tras verificar, se guardó la foto. En el teléfono emulado se recibió el correo de recuperación y se pudo entrar con la contraseña nueva. |
| Google y GitHub | En la tablet el propietario comprobó los dos proveedores y sus fotos. La foto de la cuenta anterior desapareció y **Choose photo** quedó oculto en ambas sesiones. |
| Foto sin internet | Con modo avión activo y Wi-Fi apagado, se cerró Bimbi y se terminó el proceso en segundo plano. Al abrir un proceso nuevo, se restauró la sesión y apareció la foto de esa cuenta. También se abrió **Alarms** y se restauró la conexión de la tablet. |
| Alarma de invitado | En el teléfono de 360 dp, en modo avión y sin Wi-Fi, se confirmó el registro nativo de una alarma y su eliminación al cancelarla desde Bimbi. La hora programada quedó fuera de la prueba. |
| Diseño | Se abrieron las cinco pestañas a 360 y 412 dp. En la Galaxy Tab A9, **Profile** y **Appearance** abrieron en vertical y horizontal. Se comprobó Atrás en vertical y se restauró la orientación de la tablet. |

Las pruebas físicas y los recorridos de Android están registrados junto con los comandos. Las denegaciones entre cuentas y el caso de origen OAuth con contraseña vinculada se comprobaron por separado en Firebase Emulator Suite. [Evidencia de dispositivo](REPORT.md#resultados) · [Salida de las pruebas](checks.txt)

## 11. Empaquetar el APK y dejar las comprobaciones reproducibles

La comprobación local terminó con formato y análisis limpios, 72 pruebas de Flutter, 13 del servidor y 11 de Firebase Emulator Suite. Se preparó GitHub Actions para usar Java 21, Node 22 y la versión fijada de Flutter. El flujo Linux ejecuta las verificaciones con `BIMBI_SKIP_MAC_GOLDENS=true`. Las referencias visuales de macOS se cubrieron en la ejecución local completa. La ejecución hospedada sigue pendiente de conectar un repositorio remoto. [GitHub Actions](../../../.github/workflows/ci.yml) · [Etiquetas de las pruebas visuales](../../../dart_test.yaml) · [Resultados](checks.txt)

Se compiló la variante de desarrollo con la configuración local de Firebase y se conservó una copia en `build/review` para protegerla de las compilaciones que reutilizan la ruta de salida habitual. Se verificó la firma con `apksigner` y se instaló el mismo APK como actualización en ambos dispositivos. Los siguientes comandos se ejecutan desde la raíz del proyecto, con las herramientas de Android disponibles en la terminal. [Configuración del entorno](../../SETUP.md) · [Estado de las fases](../../decisions/gates.md)

```sh
flutter build apk --debug --no-pub --dart-define-from-file=config/dev.json
mkdir -p build/review
cp build/app/outputs/flutter-apk/app-debug.apk build/review/bimbi-phase3-debug.apk
apksigner verify build/review/bimbi-phase3-debug.apk
shasum -a 256 build/review/bimbi-phase3-debug.apk
```

El APK de cierre de la Fase 3 tiene SHA-256 `608759abcd04e8028c853130f299e538c3ac7513f9d9978542b28ddfcd86ad9e`. La configuración local y el APK se guardan fuera del historial de Git. [APK de desarrollo](../../../build/review/bimbi-phase3-debug.apk) · [Compilación, firma y suma registradas](checks.txt)
