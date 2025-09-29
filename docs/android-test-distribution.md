# Android Test Distribution (Firebase App Distribution)

This repo includes a GitHub Actions workflow that builds the Android app and distributes it to Firebase App Distribution for testers.

Workflow file:
- `.github/workflows/android-firebase-distribution.yml`

It runs on:
- Pushes to `main` that modify Android/Flutter sources
- Manual runs (workflow_dispatch)

## Secrets you must set

In your GitHub repository settings (Settings → Secrets and variables → Actions → New repository secret), add:

Required for signing the release APK:
- `ANDROID_KEYSTORE_BASE64` — Base64-encoded contents of your `keystore.jks`
- `ANDROID_KEYSTORE_PASSWORD` — Keystore password
- `ANDROID_KEY_PASSWORD` — Key password
- `ANDROID_KEY_ALIAS` — Key alias

Required for Firebase App Distribution (using Firebase CLI):
- `FIREBASE_APP_ID` — Your Android app's Firebase App ID (looks like: `1:1234567890:android:abc123...`).
- `FIREBASE_TESTERS_GROUP` — App Distribution group name or comma-separated group aliases (e.g., `qa` or `android-testers`) OR emails.
- `FIREBASE_TOKEN` — Firebase CI token used by the CLI to authenticate.

Note: You can also supply testers directly instead of groups by editing the workflow to pass `--testers "email1@example.com,email2@example.com"`.

## How to get/generate values

### 1) Generate a keystore
If you don't have a release keystore yet, you can generate one with Java's `keytool`.

On Windows (PowerShell):
- Ensure JDK is installed (the workflow uses Temurin 17 in CI).
- Open PowerShell and run:

```
& "$env:JAVA_HOME\bin\keytool.exe" -genkey -v -keystore keystore.jks -alias your_alias -keyalg RSA -keysize 2048 -validity 10000
```

This will prompt you for passwords and details. Keep the alias/passwords — you'll need them for secrets.

### 2) Base64-encode the keystore (Windows PowerShell)

```
$bytes = [System.IO.File]::ReadAllBytes(".\keystore.jks");
[System.Convert]::ToBase64String($bytes)
```

Copy the output string and paste into the `ANDROID_KEYSTORE_BASE64` secret.

### 3) Firebase App ID
- In the Firebase Console → Project Settings → General → Your apps → Android app, copy the App ID (NOT the package name).
- Set as `FIREBASE_APP_ID`.

### 4) Firebase testers group
- In Firebase Console → App Distribution → Testers & Groups, create a group (e.g., `qa`).
- Set `FIREBASE_TESTERS_GROUP` to that group alias (or a comma-separated list of aliases/emails).

### 5) Firebase CI token
- Install Firebase CLI locally if needed: https://firebase.google.com/docs/cli
- Run `firebase login` and then:

```
firebase login:ci
```

- Copy the generated token and set it as `FIREBASE_TOKEN`.

## How the workflow works

1. Checks out code
2. Sets up Java 17 and Flutter (stable)
3. Decodes your base64 keystore and writes `android/key.properties` (Gradle reads this)
4. Runs `flutter pub get`
5. Builds a release APK: `flutter build apk --release`
6. Installs Firebase CLI
7. Uploads the APK to App Distribution using `firebase appdistribution:distribute ...`
8. Also uploads the APK as a workflow artifact for easy download

## Triggering the workflow

- Push to `main` affecting `lib/**`, `pubspec.yaml`, `android/**`, or the workflow file; or
- Manually run from the Actions tab → "Build Android and Upload to Firebase App Distribution" → Run workflow.

## Switching to a debug build (optional)
If you want to skip signing for early tests, you can switch to a debug build:
- In `.github/workflows/android-firebase-distribution.yml`:
  - Remove the keystore steps ("Decode Android keystore" and "Create android/key.properties").
  - Change the build step to `flutter build apk --debug`.
  - Update the upload step to point to `build/app/outputs/flutter-apk/app-debug.apk`.

This is simpler but produces a debug APK. Many distribution/testing scenarios prefer release builds to match production behavior.

## Troubleshooting
- App ID mismatch: Ensure `FIREBASE_APP_ID` matches the Android app in Firebase for this package name.
- Permission issues: Confirm `FIREBASE_TOKEN` belongs to a Google account with access to the Firebase project.
- Keystore errors: Verify alias/passwords match and that `key.properties` is correctly written by the workflow.
- Gradle/Java errors: The workflow uses Java 17; ensure your Gradle/AGP are compatible (AGP 8.x+ recommended).
