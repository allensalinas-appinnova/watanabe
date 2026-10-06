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

## Ejecutar en iOS contra el Firebase existente

El proyecto de desarrollo enlazado actualmente es `studio-2659953950-840b8`
(`watanabe`). La app iOS registrada usa el bundle ID
`co.appinnova.personalFinance`. La configuración local está en
`config/firebase.dev.json` y se excluye de Git; no se debe copiar a un archivo
versionado ni compartir en capturas o logs.

Para ejecutar en el simulador iOS:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  ./tool/run_ios_firebase.sh 5FE95D04-2888-4AAF-8D4E-F85E7407ED95
```

Este proyecto iOS integra plugins nativos usando Swift Package Manager, opción
declarada en `pubspec.yaml`. En una máquina nueva ejecuta `flutter pub get` y
deja que Xcode resuelva los paquetes en el primer build.

Sin argumento, Flutter usará su dispositivo iOS predeterminado. Para un iPhone
físico, conecta/desbloquea el teléfono, acepta Trust en el dispositivo y
configura firma de desarrollo en Xcode; lista su ID con `flutter devices` y
pásalo al script. Si Flutter no está en `PATH`, configura `FLUTTER_BIN`.
El script valida el ID del proyecto y siempre desactiva los emuladores.

## Ejecutar en Android contra el Firebase existente

La app Android quedó registrada en el proyecto con el package name
`co.appinnova.personal_finance`. Sus Dart defines locales se guardan en
`config/firebase.dev.android.json`, excluido de Git y separado de las opciones
iOS porque el `appId` de Firebase es específico por plataforma.

En VS Code, selecciona el dispositivo Android en la barra de estado, elige
**ClearBudget · Firebase real (Android)** en Run and Debug y presiona F5. El
perfil pasa `USE_FIREBASE_EMULATORS=false`; por tanto, opera contra el proyecto
Firebase real. En un teléfono físico habilita USB debugging, conecta y acepta
el diálogo de autorización. En un emulador Android, inicia primero el AVD.

La inicialización usa Dart defines, por lo que no necesita `google-services.json`
ni el Gradle plugin Google Services para proporcionar `FirebaseOptions`. Para
Google Sign-In en Android, registra SHA-1/SHA-256 del certificado debug y
verifica que el proveedor Google esté habilitado en Firebase Authentication;
esto no es requisito para abrir la app o usar otro proveedor ya habilitado.

Google Sign-In requiere que Google esté habilitado como proveedor de Firebase
Authentication y que el OAuth client esté asociado al bundle ID. El URL scheme
reverso del client iOS ya está en `ios/Runner/Info.plist`. Los proveedores
habilitados en Firebase Console deben comprobarse antes de probar el login; no
activar ni desplegar proveedores sin revisar el impacto sobre la app web que
comparte el proyecto.

La configuración no apunta a `staging` ni `prod`: el proyecto Firebase real
seleccionado es compartido con el producto web, así que usa una cuenta de prueba
propia y evita ejecutar pruebas automatizadas o crear datos de prueba allí.

Para CI, cada entorno debe tener su propio grupo de secretos y su propio bundle/application ID cuando la distribución lo requiera. La configuración nativa `google-services.json` y `GoogleService-Info.plist` debe gestionarse fuera del repositorio o mediante perfiles seguros del pipeline.

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

```bash
E2E_PLATFORM=ios \
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
PATH="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home/bin:/Users/allensalinas/dev/tools/flutter/bin:$PATH" \
./tool/run_emulator_e2e.sh 5FE95D04-2888-4AAF-8D4E-F85E7407ED95
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
