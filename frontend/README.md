# MedicTri - Flutter Mobile Frontend (`triagemy`)

The mobile client application for the MedicTri Emergency Triage & Hospital Routing System.

## Overview

One app with two sides, chosen on the start screen:
- **Patient**: triage chat (`/api/triage/chat`), triage report with PDF export, hospital recommendations and map, visit progress, family access, profile. English and Malay.
- **Admin (hospital staff)**: emergency queue, check-in, stage logging, tests, diagnosis notes and patient lookup.

The primary demo target is Flutter Web (Chrome). The backend must be running (see the [root README](../README.md)).

## Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (Dart SDK 3.x)
- Android Studio / Xcode / VS Code with Flutter extension
- An emulator or physical device

### Installation & Run

1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```

2. Fetch Flutter dependencies:
   ```bash
   flutter pub get
   ```

3. Run the application:
   ```bash
   flutter run
   ```

To specify a target device (e.g. Chrome, Windows desktop, or a connected mobile emulator):
```bash
flutter run -d chrome
# or
flutter run -d windows
```

## Project Structure

```
frontend/
├── lib/
│   ├── main.dart                 # Entry point → role selection (patient / admin)
│   ├── theme.dart                # Gradient design system
│   ├── localization.dart         # English / Malay strings
│   ├── countries.dart            # Country list for sign-up
│   ├── screens/                  # Role selection, login, sign-up, forgot password
│   ├── pages/                    # Home, triage chat, report, routing, hospitals map, progress, profile, notifications
│   ├── admin/                    # Staff app: queue, check-in, patient detail, diagnosis, PDF, i18n
│   ├── services/                 # API base URL, auth, triage chat, hospitals, GPS
│   └── widgets/                  # Hospital card, family access card, visit history
├── test/                         # Widget and unit tests
├── web/ android/ ios/ ...        # Platform projects
└── pubspec.yaml
```

## Checks

```bash
flutter analyze
flutter test
```
