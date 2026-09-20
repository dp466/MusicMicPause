# Xcode Cloud Submission — Mic Pause 1.0

> Historical App Store preparation notes from July 2026. Recheck Store requirements before submission. For current GitHub packaging and signing, see [release instructions](../docs/RELEASING.md).

Use this route while the development Mac can run only Xcode 27 beta.

## Why

As of July 28, 2026, App Store Connect accepts Xcode 27 beta 4 builds for
internal and external TestFlight testing only. Apple’s latest listed production
toolchain is Xcode 26.6. The installed Xcode 27 build is `27A5194q`, so it must
not be used to create the production App Store archive.

Apple status:
<https://developer.apple.com/help/app-store-connect/release-notes/>

## One-time setup

1. Push the release commit to the connected Git repository.
2. Create the macOS app record in App Store Connect with bundle ID
   `com.dparadis.MicPause`.
3. Open `MicPause.xcodeproj` in Xcode 27 beta and sign in to the Apple Developer
   account for team `QU4R4G95KN`.
4. Choose **Product → Xcode Cloud → Create Workflow**.
5. Select the shared `MicPause` scheme and the macOS product.
6. Connect the GitHub repository when prompted.
7. Edit the workflow environment and select the latest available **release**
   Xcode that App Store Connect accepts for production (currently Xcode 26.6),
   with a compatible release macOS environment.
8. Add an **Archive** action for the macOS app and configure it for App Store
   distribution. Keep automatic signing enabled.
9. Start the workflow from the exact release commit.

Apple’s Xcode Cloud workflow reference:
<https://developer.apple.com/documentation/xcode/xcode-cloud-workflow-reference>

## Submit

1. Wait for the cloud archive and App Store Connect processing to complete.
2. Open **App Store Connect → Apps → Mic Pause → macOS 1.0**.
3. In **Build**, select the processed Xcode Cloud build.
4. Resolve export-compliance questions if App Store Connect shows **Missing
   Compliance**.
5. Complete metadata, screenshots, privacy, age rating, App Review contact,
   storefront, and DSA information.
6. Add version 1.0 to the App Review submission and submit.

Download and retain the Xcode Cloud archive artifact after the successful
release build. Apple retains Xcode Cloud artifacts for a limited period.
