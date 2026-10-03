# MedicTri - Flutter Mobile Frontend (`triagemy`)

The mobile client application for the MedicTri Emergency Triage & Hospital Routing System.

## Overview

The mobile frontend provides:
- Patient triage assessment questionnaire and symptom input
- Real-time communication with the FastAPI backend
- Hospital recommendations, routing, and emergency facility status

## Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.13.4 or higher)
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
│   ├── main.dart                 # Application entry point
│   └── screens/
│       └── login_screen.dart     # Authentication & initial screen
├── test/
│   └── widget_test.dart          # Widget tests
├── android/                      # Android native project files
├── ios/                          # iOS native project files
├── web/                          # Web platform files
├── windows/                      # Windows desktop files
├── macos/                        # macOS desktop files
├── linux/                        # Linux desktop files
├── pubspec.yaml                  # Flutter package dependencies
└── analysis_options.yaml         # Lint rules & static analysis configuration
```
