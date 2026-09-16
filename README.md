# DriversApp — App para conductores

App móvil (Flutter) para conductores de una plataforma de transporte. Parte del proyecto DriversApp:
[API](https://github.com/StephanSuarez/driversapp-api) · [Panel admin](https://github.com/StephanSuarez/driversapp-admin) · [Web pública](https://github.com/StephanSuarez/driversapp-web)

**Caso de estudio con video y capturas:** https://stephansuarez.github.io/driversapp-site/

## Qué hace

- **Registro y verificación**: alta con celular, código OTP y contraseña.
- **Onboarding de documentos con IA en el dispositivo** (Google ML Kit):
  - OCR de licencia, tarjeta de propiedad y tarjetón.
  - Detección de rostro en la foto de perfil.
  - Etiquetado de imágenes para validar las fotos del vehículo.
- **Modo conectado**: reporta la ubicación GPS al backend en intervalos configurables.
- **Viajes**: recibe solicitudes, ve la ruta en el mapa (Mapbox), chatea con el cliente por WebSocket, cobra y califica al cliente.
- **Notificaciones push** (Firebase Cloud Messaging) y avisos por voz (text-to-speech).
- **Membresía**: gestión de la suscripción del conductor.

## Stack

Flutter · Dart · Mapbox Maps · Google ML Kit · Firebase Messaging · WebSockets · Geolocator

## Correr en local

```bash
cp .env.example .env        # completa MAPBOX_TOKEN y la URL del API
flutter pub get
flutter run
```

Para push notifications agrega tu propia configuración de Firebase (no está en el repo):
`android/app/google-services.json` y `ios/Runner/GoogleService-Info.plist`.

## Equipo

- [@StephanSuarez](https://github.com/StephanSuarez)
- [@jhonatandgomez](https://github.com/jhonatandgomez)

## Créditos

Modelo 3D del taxi: ["Taxi 2"](https://sketchfab.com/3d-models/taxi-2-0b5310fbf2c14b3e807c63f2ee1ca7bf) de [solid3DDD](https://sketchfab.com/solid3ddd), con licencia [CC BY 4.0](http://creativecommons.org/licenses/by/4.0/).
