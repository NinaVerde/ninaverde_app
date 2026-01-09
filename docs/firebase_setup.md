# Firebase setup (local-only config)

Keep Firebase secrets out of source control by storing platform config files
locally and providing the required values at build time.

## Local config files

Copy the example templates and fill in your project-specific values:

```sh
cp android/app/google-services.json.example android/app/google-services.json
cp ios/Runner/GoogleService-Info.plist.example ios/Runner/GoogleService-Info.plist
cp macos/Runner/GoogleService-Info.plist.example macos/Runner/GoogleService-Info.plist
```

## Build-time values

Provide the matching values for each platform using `--dart-define`.

Example (Android):

```sh
flutter run \
  --dart-define=FIREBASE_ANDROID_API_KEY=... \
  --dart-define=FIREBASE_ANDROID_APP_ID=... \
  --dart-define=FIREBASE_ANDROID_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_ANDROID_PROJECT_ID=... \
  --dart-define=FIREBASE_ANDROID_STORAGE_BUCKET=...
```

For web, provide the `FIREBASE_WEB_*` values (API key, app id, sender id,
project id, auth domain, storage bucket, and optional measurement id). For iOS,
macOS, and Windows, provide the platform-specific `FIREBASE_<PLATFORM>_*`
entries referenced in `lib/firebase_options.dart`.
