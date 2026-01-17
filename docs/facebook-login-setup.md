# Facebook Login Setup (Native SDK + Firebase Auth)

This app uses the native Meta SDK on Android and iOS, and Firebase Auth for the
token exchange. Web uses Firebase popup sign-in.

## Meta app settings

1) Meta App -> Settings -> Basic:
   - App ID: 1449626349514795
   - Client Token: 9ca8cb1113725c94268ee347af5bc1f9
   - App Secret: keep only in Firebase (never in app code)

2) Meta App -> Facebook Login -> Settings:
   - Valid OAuth Redirect URIs:
     https://e-commerce-nina-verde-vy-451f6.firebaseapp.com/__/auth/handler
   - Key Hashes:
     - Debug: generate and paste from the command below
     - Release: add when a release keystore is created

3) Meta App -> Settings -> Basic -> Add Platform:
   - Android
     - Package: com.nicaraguaninaverde.theapp
     - Class: com.nicaraguaninaverde.theapp.MainActivity
   - iOS
     - Bundle ID: com.nicaraguaninaverde.theapp (or the actual iOS bundle id)

## Firebase settings

Firebase Console -> Authentication -> Sign-in method -> Facebook:
- Enable Facebook provider
- App ID: 1449626349514795
- App Secret: use the latest Meta App Secret
- Copy the OAuth Redirect URI into Meta (see above)

## Android debug key hash (Windows PowerShell)

Run this from PowerShell and paste the output into Meta -> Key Hashes.

```
$cert = keytool -exportcert -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android -keypass android -rfc
$base64 = ($cert | Select-String -Pattern "BEGIN CERTIFICATE|END CERTIFICATE" -NotMatch) -join ""
$bytes = [Convert]::FromBase64String($base64)
$sha1 = [System.Security.Cryptography.SHA1]::Create().ComputeHash($bytes)
[Convert]::ToBase64String($sha1)
```

Example debug key hash used in dev:
6kSAnXsgKn0BmABKm18+g69EOwI=

## iOS notes

From macOS, run:

```
cd ios
pod install
```

## Implementation overview

- Android config: android/app/src/main/AndroidManifest.xml
- Android strings: android/app/src/main/res/values/strings.xml
- Android native bridge: android/app/src/main/kotlin/com/nicaraguaninaverde/theapp/MainActivity.kt
- iOS Info.plist: ios/Runner/Info.plist
- iOS native bridge: ios/Runner/AppDelegate.swift
- Flutter flow: lib/screens/login_screen.dart

