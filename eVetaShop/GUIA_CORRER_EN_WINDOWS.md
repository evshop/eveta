# Guía rápida (Windows): instalar Flutter y correr este proyecto

Este proyecto es un template viejo y en `pubspec.yaml` tiene:

- `environment: sdk: ">=2.2.0 <3.0.0"`

Eso significa que con el Flutter más nuevo (Dart 3) normalmente te va a fallar `flutter pub get`. Para verlo correr rápido, usa un Flutter 1.x (Dart 2).

## 1) Instalar Flutter (recomendado para este repo: Flutter 1.22.6)

1. Ve al archivo de releases: https://docs.flutter.dev/release/archive
2. Descarga **Flutter 1.22.6 (stable) para Windows** (zip).
3. Extrae el zip en una ruta corta, por ejemplo:
   - `C:\src\flutter`
4. Agrega Flutter al `PATH`:
   - Variables de entorno → `Path` → agregar `C:\src\flutter\bin`
5. Cierra y abre de nuevo la terminal, y verifica:

```powershell
flutter --version
```

## 2) Preparar Android (para poder ejecutar la app)

1. Instala Android Studio: https://developer.android.com/studio
2. En Android Studio, instala:
   - Android SDK Platform (una versión reciente)
   - Android SDK Build-Tools
   - Android SDK Platform-Tools
   - Android SDK Command-line Tools (latest)
3. Abre el SDK Manager y asegúrate de tener instalado al menos **un emulador** (AVD) o conecta un teléfono con depuración USB.

Luego ejecuta:

```powershell
flutter doctor
flutter doctor --android-licenses
```

Y arregla lo que marque como `✗` (sobre todo Android toolchain y licencias).

## 3) Correr este proyecto

Desde la carpeta del repo:

```powershell
flutter pub get
flutter run
```

Si tienes más de un dispositivo/emulador:

```powershell
flutter devices
flutter run -d <deviceId>
```

## 4) Notas comunes

- En Windows no puedes compilar iOS (para iOS necesitas macOS).
- Si instalaste Flutter “último” (Dart 3) y falla por la versión de SDK, tienes 2 caminos:
  - Usar Flutter 1.x (rápido para ver el template tal cual).
  - Migrar el proyecto a Flutter moderno (yo te lo puedo actualizar después).

