# Parent Bus Tracker (Flutter Frontend)

Frontend-first Flutter app for a parent school-bus tracking experience with very low cognitive load.

## Implemented Scope

- `3 tabs only`: `Home`, `Map`, `Profile`
- `OTP-only` authentication flow (mobile + OTP)
- Home control center with:
  - profile card
  - mini segmented panel (`ETA`, `Admin`, `Map`)
  - vertical stop progression tracker
  - smart alert banner states
- Map tab with `flutter_map` (Leaflet-compatible):
  - route polyline
  - stop markers
  - animated-like live bus marker updates
  - stale GPS and journey state messaging
- Profile tab with route overview/change placeholder, preferences, emergency details, logout

## Architecture

Clean layered direction (lightweight implementation):

- `presentation`: `lib/screens/`
- `domain state`: `lib/app_state.dart`
- `data/services`: `lib/services/` (existing)

State management: Riverpod  
Navigation: GoRouter  
Networking-ready: Dio  
Map: flutter_map + OpenStreetMap tiles

## Setup

1. Install Flutter SDK (stable)
2. Run:
   - `flutter pub get`
   - `flutter run`

## Environment

Keep `.env` for runtime URLs and keys. Example fields:

- `BASE_URL=https://api.example.com`
- `OPENROUTESERVICE_API_KEY=your_key_here`
- `FCM_SENDER_ID=your_sender_id`

## Notes

- Real APIs, FCM background handlers, and OpenRouteService polyline fetching are documented in `api.md`.
- Live tracking polls the backend on a **low-frequency** interval (see `lib/app_state.dart`) and supports **pull-to-refresh** on Home, Map, and Profile; map auto-follow is **debounced** to avoid jitter.
- Repo root `README.md` explains scheduled sync logs and Firestore read/write tuning.
