# iOS TestFlight Distribution (CI)

This pipeline builds a signed IPA on macOS runners and uploads it to TestFlight using App Store Connect API keys.

## Prerequisites

1. Apple Developer Program (Individual or Organization)
2. App in App Store Connect with the same Bundle ID as your Flutter app
3. A Distribution Certificate (.p12) and an App Store provisioning profile
4. App Store Connect API key (Key ID, Issuer ID, and private key .p8)

## Required GitHub Secrets

Add these secrets in your GitHub repo settings:

- APP_STORE_CONNECT_API_KEY_ID — the API key’s Key ID
- APP_STORE_CONNECT_API_ISSUER_ID — the API key’s Issuer ID
- APP_STORE_CONNECT_API_KEY_BASE64 — base64 of the .p8 contents
- IOS_CERT_P12_BASE64 — base64 of the distribution certificate .p12
- IOS_CERT_PASSWORD — password for the .p12 (empty if none)
- IOS_PROVISIONING_PROFILE_BASE64 — base64 of the provisioning profile (.mobileprovision)
- IOS_PROFILE_NAME — a short name to save the profile as (e.g., Kingdom_Prod_AppStore)
- IOS_BUNDLE_ID — the bundle identifier (e.g., com.example.kingdom)
- TESTFLIGHT_GROUPS — optional, comma-separated TestFlight groups to auto-assign

## How to generate the files

- Certificate (.p12):
  - Create/Download an iOS Distribution certificate in Apple Developer portal
  - Export as .p12 from Keychain Access (include private key)
  - Convert to base64: `base64 -i dist.p12 | pbcopy`

- Provisioning profile (.mobileprovision):
  - Create App Store profile for your Bundle ID
  - Download and convert to base64: `base64 -i profile.mobileprovision | pbcopy`

- App Store Connect API key (.p8):
  - Create Key in App Store Connect → Users and Access → Keys
  - Download the .p8 and convert to base64: `base64 -i AuthKey_XXXXXX.p8 | pbcopy`

## Triggering the workflow

Push to Testing or main (changes to lib/**, ios/**, pubspec.yaml, or the workflow file).

The workflow will:
- Set up Flutter and Xcode
- Install signing cert + provisioning profile to a temp keychain
- Build a release IPA with manual signing via ExportOptions.plist
- Upload to TestFlight using fastlane pilot

## Notes

- By default this uploads for processing; set TESTFLIGHT_GROUPS to auto-assign external testers.
- If your signing is “Automatic”, you can remove the manual signing steps and use Xcode-managed profiles, but CI typically works more reliably with manual profiles.
- Build numbers must be unique per upload. If you need auto-bump, we can add a step to bump CFBundleVersion.
- To speed up uploads, keep your IPA small (avoid unneeded assets) and ensure Apple services aren’t degraded.
