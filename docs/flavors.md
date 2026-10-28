# Entornos y Firebase Flavors

## Entornos

| Entorno | Propósito | Firebase esperado |
| --- | --- | --- |
| `dev` | Desarrollo local y emuladores | Proyecto aislado de desarrollo |
| `staging` | QA, pruebas integradas y pre-release | Proyecto de validación |
| `prod` | Distribución y usuarios reales | Proyecto productivo con reglas reforzadas |

## Selección en runtime

`AppEnvironment.fromDartDefine()` lee `APP_ENV`; por defecto usa `dev`. Los parámetros de Firebase se entregan como defines de compilación y nunca se escriben en el repositorio.

Ejemplo:

```bash
flutter run \
  --dart-define=APP_ENV=dev \
  --dart-define=FIREBASE_DEV_API_KEY=... \
  --dart-define=FIREBASE_DEV_APP_ID=... \
  --dart-define=FIREBASE_DEV_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_DEV_PROJECT_ID=...
```

Use the `FIREBASE_STAGING_*` or `FIREBASE_PROD_*` define family when selecting
those respective environments. The application options are selected from
`APP_ENV` in `lib/core/firebase/firebase_options.dart`.

Invalid `APP_ENV` values now fail fast. Emulator mode is accepted only with
`APP_ENV=dev` and is rejected in release builds. Staging and production require
all required Firebase values; empty options are not accepted.

Firebase app IDs are platform-specific. Copy the corresponding example to the
ignored platform file, fill it using the Firebase CLI output, and run:

```bash
cp config/firebase.staging.android.example.json config/firebase.staging.android.json
cp config/firebase.staging.ios.example.json config/firebase.staging.ios.json
./tool/verify_release_config.sh staging android
./tool/verify_release_config.sh staging ios
```

Retrieve the native SDK values from the authenticated Firebase CLI with the
staging project and the registered app IDs:

```bash
npx -y firebase-tools@latest login --reauth
npx -y firebase-tools@latest apps:list --project <STAGING_PROJECT_ID>
npx -y firebase-tools@latest apps:sdkconfig ANDROID <ANDROID_APP_ID> --project <STAGING_PROJECT_ID>
npx -y firebase-tools@latest apps:sdkconfig IOS <IOS_APP_ID> --project <STAGING_PROJECT_ID>
```

Map the returned values to the `FIREBASE_STAGING_*` keys; do not commit these
files. The checks intentionally fail until the staging project, Android upload
key and iOS development team are configured. They do not deploy or mutate
Firebase.

## Ejecutar en iOS contra el nuevo Firebase

El proyecto Firebase nuevo es `lumiomoney`. El bundle ID de iOS y el package
name Android del código son `com.appinnova.lumiomoney`; ambos están registrados
en este proyecto según los archivos de configuración locales. La configuración
iOS local está en
`config/firebase.dev.json` y se excluye de Git; no se debe copiar a un archivo
versionado ni compartir en capturas o logs.

Para ejecutar en el simulador iOS:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  ./tool/run_ios_firebase.sh <simulator-or-device-id>
```

Este proyecto iOS integra plugins nativos usando Swift Package Manager, opción
declarada en `pubspec.yaml`. En una máquina nueva ejecuta `flutter pub get` y
deja que Xcode resuelva los paquetes en el primer build.

Sin argumento, Flutter usará su dispositivo iOS predeterminado. Para un iPhone
físico, conecta/desbloquea el teléfono, acepta Trust en el dispositivo y
configura firma de desarrollo en Xcode; lista su ID con `flutter devices` y
pásalo al script. Si Flutter no está en `PATH`, configura `FLUTTER_BIN`.
El script valida el ID del proyecto y siempre desactiva los emuladores.

Para una revisión manual en un iPhone conectado con Flutter Driver, usa el
entry point QA aislado:

```bash
FLUTTER_BIN=/Users/allensalinas/dev/tools/flutter/bin/flutter \
  bash tool/run_ios_qa.sh <iphone-device-id>
```

Este comando valida que el archivo local `config/firebase.dev.json` apunte a
`lumiomoney`, desactiva explícitamente los emuladores y lanza
`test_driver/main_qa.dart`. Ese entry point solo permite modo debug y habilita la
extensión necesaria para inspección e interacción táctil; `lib/main.dart` y los
builds de distribución no la incluyen. Úsalo únicamente con una cuenta QA
autorizada y datos sintéticos. No ejecutes `integration_test` ni suites
automatizadas contra el Firebase real; para ellas usa exclusivamente
`demo-clearbudget`.

## Ejecutar en Android contra el nuevo Firebase

Los Dart defines Android locales se guardan en
`config/firebase.dev.android.json`, excluido de Git y separado de las opciones
iOS porque el `appId` de Firebase es específico por plataforma.

En VS Code, selecciona el dispositivo Android en la barra de estado, elige
**LumioMoney · Firebase real (Android)** en Run and Debug y presiona F5. El
perfil pasa `USE_FIREBASE_EMULATORS=false`; por tanto, opera contra el proyecto
Firebase real. En un teléfono físico habilita USB debugging, conecta y acepta
el diálogo de autorización. En un emulador Android, inicia primero el AVD.

La inicialización de Firebase usa Dart defines, así que no depende de
`google-services.json` para proporcionar `FirebaseOptions`. Crashlytics sí
requiere el archivo nativo y los plugins Gradle de Google Services y Crashlytics;
el archivo local se excluye de Git. Para Google Sign-In en Android, registra SHA-1/SHA-256 del certificado debug y
verifica que el proveedor Google esté habilitado en Firebase Authentication;
esto no es requisito para abrir la app o usar otro proveedor ya habilitado.

Google Sign-In requiere que Google esté habilitado como proveedor de Firebase
Authentication y que el OAuth client esté asociado al bundle ID. El URL scheme
reverso del nuevo client iOS está en `ios/Runner/Info.plist`, y los archivos
locales ignorados incluyen el Web OAuth client ID. El archivo Android recibido
contiene un Web OAuth client pero no un Android OAuth client; añade las huellas
SHA-1/SHA-256 de los certificados debug y release a la app Android en Firebase
Console y descarga la configuración actualizada antes de probar Google Sign-In.

En un proyecto recién creado, habilita los proveedores de Authentication que
vayas a probar (email/password se usa en el flujo normal), crea la base de datos
Cloud Firestore en la región deseada e inicializa Cloud Storage si vas a usarlo.
Revisa las reglas de Firestore y Storage antes de cargar datos reales. La
configuración local no crea servicios ni despliega reglas.

El catálogo global de categorías se inicializa por separado del perfil de cada
usuario. Para sembrar únicamente los documentos faltantes en el proyecto
`lumiomoney`, autentícate localmente con Google Cloud Application Default
Credentials (ADC) y usa una cuenta con permisos de escritura de Firestore; luego
ejecuta `npm --prefix functions run seed:catalog:real`. Este comando está fijado
a `lumiomoney`, rechaza el uso de un host de emulador y preserva documentos
existentes. El comando `npm --prefix functions run seed:catalog` continúa siendo
exclusivo del emulador `demo-clearbudget`.

La configuración `dev` apunta al proyecto Firebase real `lumiomoney`, no a
`staging` ni `prod`. Usa cuentas de prueba propias y no ejecutes E2E automatizados
contra ese proyecto; las pruebas automatizadas deben permanecer aisladas en
`demo-clearbudget`.

Para CI, cada entorno debe tener su propio grupo de secretos y su propio bundle/application ID cuando la distribución lo requiera. La configuración nativa `google-services.json` y `GoogleService-Info.plist` debe gestionarse fuera del repositorio o mediante perfiles seguros del pipeline.

Crashlytics usa `android/app/google-services.json` y
`ios/Runner/GoogleService-Info.plist` localmente, ambos excluidos de Git. El
registro iOS de Firebase debe coincidir con `com.appinnova.lumiomoney.app`.
La recolección queda deshabilitada por defecto en metadatos nativos y solo se
activa explícitamente en `staging` o `prod`, nunca con Emulator. Consulta
`docs/observability.md` para la política de privacidad, simbolicación y estado
de validación remota.

## Google Sign-In nativo

El botón de Google utiliza `google_sign_in` en Android/iOS y Firebase Auth para
intercambiar el ID token. Para habilitarlo en un entorno real:

1. Activar Google como proveedor en Firebase Authentication.
2. Registrar el SHA-1/SHA-256 del certificado y el `applicationId` de cada
   variante Android en el proyecto Firebase.
3. Proveer las opciones nativas correspondientes al flavor y configurar el
   OAuth client de tipo Web. Para builds por Dart defines, entregar el client ID
   Web con `GOOGLE_SERVER_CLIENT_ID`; `GOOGLE_CLIENT_ID` queda disponible para
   el client ID de plataforma donde se requiera.
4. En iOS, registrar el URL scheme reverso del client ID en `Info.plist` según
   la configuración de Google Sign-In.

La autenticación federada real no se ejecuta contra el Emulator Suite: requiere
cuentas y configuración OAuth externas. El flujo email/contraseña, registro,
recuperación, invitado y persistencia Firestore sí se cubren localmente.

## Pruebas E2E con Firebase Emulator Suite

Las pruebas E2E siempre usan el proyecto ficticio `demo-clearbudget`; nunca
usan el archivo local de Firebase real. Con el simulador iOS 17e ya iniciado:

Antes de la primera ejecución, configura Xcode completo como el directorio
activo de herramientas (los hooks nativos no resuelven el SDK iOS si `xcode-select -p`
apunta a Command Line Tools):

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

```bash
E2E_PLATFORM=ios \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
PATH="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home/bin:/Users/allensalinas/dev/tools/flutter/bin:$PATH" \
./tool/run_emulator_e2e.sh <simulator-id>
```

En Android, inicia un emulador y ejecuta
`./tool/run_emulator_e2e.sh <device-id>`; el host predeterminado para acceder
al Emulator Suite desde Android es `10.0.2.2`, y desde iOS es `127.0.0.1`.
El script arranca Auth, Firestore y Storage en los puertos altos definidos en
`firebase.json`, ejecuta el flujo de autenticación y apaga los emuladores al
terminar. Para cambiar el host, define `FIREBASE_EMULATOR_HOST`.

## Reglas de seguridad

- No reutilizar proyectos Firebase entre `staging` y `prod`.
- No guardar tokens, API credentials completas ni archivos de configuración productivos en Git.
- Separar Analytics, Crashlytics y Storage por proyecto Firebase.
- Verificar reglas Firestore y Storage con emuladores antes de promover a `staging`.
- Proteger los builds release con revisión de flavor y firma del pipeline.
- Android release no usa la firma debug; configure `android/key.properties` from
  `android/key.properties.example` and use Play App Signing for the upload key.
- iOS release requires a real `DEVELOPMENT_TEAM`, signing certificate and
  provisioning profile supplied by Xcode/CI.

## Próximo paso de plataforma

Cuando se definan los IDs finales de Android/iOS, ejecutar FlutterFire CLI por entorno para generar opciones nativas verificadas y conectar los archivos de configuración de cada flavor al pipeline de CI.
