# HealthDoc Mobile App

Home Health Documentation Platform - Flutter iOS Application

## Project Structure

```
lib/
├── main.dart
├── app.dart
├── config/
│   ├── app_config.dart
│   └── environment.dart
├── core/
│   ├── constants/
│   ├── theme/
│   ├── utils/
│   └── errors/
├── data/
│   ├── models/
│   ├── repositories/
│   ├── datasources/
│   │   ├── local/
│   │   └── remote/
│   └── database/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
├── presentation/
│   ├── providers/
│   ├── screens/
│   ├── widgets/
│   └── routes/
└── services/
    ├── audio/
    ├── storage/
    ├── upload/
    ├── encryption/
    └── network/
```

## Setup Instructions

1. Install Flutter dependencies:
   ```bash
   flutter pub get
   ```

2. Generate code (for drift, json_serializable):
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## Configuration

Create a `.env` file in the root directory with:
```
API_BASE_URL=your_backend_url
API_TIMEOUT=30000
```

## Architecture

- **Clean Architecture**: Separation of concerns with domain, data, and presentation layers
- **Offline-First**: All recordings work offline, sync when online
- **State Management**: Riverpod for state management
- **Local Storage**: Drift (SQLite) for structured data, encrypted files for audio

## Milestone 1 Features

- ✅ Authentication
- ✅ Audio Recording (offline)
- ✅ Encrypted Local Storage
- ✅ Background Upload with Retry
