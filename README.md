# Kingdom

A gamified finance + fitness kingdom tracker

## Onboarding & Auth

An onboarding flow is included with Google Sign-In, optional password linking, username, and faction selection. It stores users in Firebase Auth and profile fields in Firestore.

### One-time Firebase setup

1) Install FlutterFire CLI (once):

	- dart pub global activate flutterfire_cli

2) Create a Firebase project in the Firebase console.

3) Configure platforms for this app from the repo root:

	- flutterfire configure --project <your-project-id> --out lib/firebase_options.dart

	This generates `lib/firebase_options.dart` and updates platform configs.

4) Android (Kotlin DSL) notes:

	Ensure the Google Services plugin is applied in `android/build.gradle.kts` and `android/app/build.gradle.kts` per FlutterFire docs. The FlutterFire CLI usually wires this automatically; if not, follow:

	- In `android/build.gradle.kts` buildscript, add classpath("com.google.gms:google-services:4.4.2")
	- In `android/app/build.gradle.kts`, apply plugin("com.google.gms.google-services")

5) iOS/macOS: open the generated Xcode workspace after configure, ensure `GoogleService-Info.plist` is present.

6) Fetch packages:

	- flutter pub get

### Run

- flutter run

On first launch, you'll see the onboarding sequence:

1) Continue with Google (creates/signs-in user in Firebase Auth)
2) Set a password (links email/password to the same account; optional but available)
3) Choose username (saved to users/{uid} in Firestore and displayName)
4) Choose faction (saved to users/{uid} in Firestore)
5) App proceeds to the main AppShell.
# kingdom

