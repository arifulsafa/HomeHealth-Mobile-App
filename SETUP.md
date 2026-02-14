# HealthDoc Mobile App - Setup Guide

## Prerequisites

1. **Flutter SDK**: Install Flutter 3.0.0 or higher
   ```bash
   flutter --version
   ```

2. **iOS Development** (for iOS builds):
   - Xcode 14.0 or higher
   - CocoaPods: `sudo gem install cocoapods`

3. **Android Development** (for Android builds):
   - Android Studio
   - Android SDK (API level 21+)

## Initial Setup

1. **Install Dependencies**
   ```bash
   flutter pub get
   ```

2. **Generate Code** (for Drift, JSON serialization)
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

3. **iOS Setup** (if building for iOS)
   ```bash
   cd ios
   pod install
   cd ..
   ```

## Configuration

### Backend API Configuration

Update `lib/config/app_config.dart` with your backend API URL:

```dart
static String apiBaseUrl = 'https://your-backend-url.com/api';
```

Or use environment-based configuration in `lib/config/environment.dart`.

### Environment Variables (Optional)

Create a `.env` file in the root directory:
```
API_BASE_URL=https://your-backend-url.com/api
API_TIMEOUT=30000
```

## Running the App

### Development
```bash
flutter run
```

### iOS
```bash
flutter run -d ios
```

### Android
```bash
flutter run -d android
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── app.dart                  # Main app widget
├── config/                   # Configuration files
├── core/                     # Core utilities, theme, constants
├── data/                     # Data layer (repositories, models)
├── domain/                   # Domain layer (entities, use cases)
├── presentation/             # UI layer (screens, widgets, routes)
└── services/                 # Services (audio, storage, upload, etc.)
```

## Key Features Implemented (Milestone 1)

✅ **Authentication UI**
- Login screen matching HealthDoc design
- Sign up screen
- Form validation

✅ **Audio Recording Service**
- Offline audio recording
- Duration tracking
- Pause/resume functionality

✅ **Encrypted Local Storage**
- AES-256 encryption for audio files
- Secure key management
- Encrypted file storage

✅ **Background Upload Service**
- Automatic upload when online
- Retry logic with exponential backoff
- Progress tracking

✅ **Network Layer**
- API client with authentication
- Error handling
- Token management

## Next Steps

1. **Connect Backend API**
   - Update API endpoints in `ApiClient`
   - Implement authentication endpoints
   - Test API integration

2. **Implement Recording Screen**
   - Form type selection (1-4 forms)
   - Patient identifier input
   - Recording controls UI

3. **Local Database**
   - Set up Drift database for offline storage
   - Store recording sessions locally
   - Implement sync queue

4. **Background Tasks**
   - Set up Workmanager for background uploads
   - Implement upload queue processing
   - Handle retry logic

## Testing

Run tests:
```bash
flutter test
```

## Building for Production

### iOS
```bash
flutter build ios --release
```

### Android
```bash
flutter build apk --release
```

## Troubleshooting

### Common Issues

1. **Pod install fails (iOS)**
   ```bash
   cd ios
   pod deintegrate
   pod install
   cd ..
   ```

2. **Build errors**
   ```bash
   flutter clean
   flutter pub get
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

3. **Permission issues**
   - Check Info.plist (iOS) for microphone permissions
   - Check AndroidManifest.xml for permissions

## Notes

- The app is configured for a custom Node.js + MongoDB backend (not Supabase)
- All API endpoints should be updated when backend is ready
- Audio files are encrypted before local storage
- Upload service includes retry logic with exponential backoff
- Session timeout is set to 30 minutes (configurable)
