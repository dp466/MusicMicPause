# App Store Submission Checklist

## Owner decisions and account setup

- [x] Set version 1.0 to **Free**.
- [ ] Confirm storefront availability.
- [x] Paid-app tax and banking setup is not required for this free release.
- [ ] Complete Digital Services Act trader-status information if distributing
      in the European Union.
- [x] Use `dparadis466@gmail.com` as the public support email address.
- [ ] Confirm `Dilan Paradis` is the correct copyright owner name.
- [ ] Confirm the final bundle identifier is `com.dparadis.MicPause`.

## Developer account and signing

- [ ] Create the App Store Connect macOS app record.
- [ ] Register or select the matching App ID.
- [x] Set Apple Developer Team `QU4R4G95KN` in the Xcode project.
- [ ] Use Xcode Cloud automatic signing, or install an Apple Distribution
      certificate if archiving locally.
- [ ] Keep build `1` for the first upload; increment it for every replacement.
- [ ] Archive with Xcode Cloud using a currently supported **release** Xcode
      (recommended on this Mac), or with a supported local release Xcode.
      Apple currently accepts Xcode 27 beta 4 builds only for TestFlight, not
      production App Store submissions.

## Website and metadata

- [x] Add the public support email to `website/app/support/page.tsx`.
- [ ] Set `NEXT_PUBLIC_SITE_URL` to the final HTTPS origin.
- [ ] Publish the website.
- [ ] Enter the resulting `/privacy` and `/support` URLs.
- [ ] Do not use the supplied iPerf Pulse Gist as Mic Pause’s Support URL.
      Publish the prepared website or create a separate Mic Pause Gist from
      `MicPauseSupport.md`.
- [ ] Paste the values from `Metadata.md`.
- [ ] Complete App Privacy as **Data Not Collected**, provided the
      implementation remains unchanged.
- [ ] Complete the age-rating questionnaire using the answers in `Metadata.md`.
- [ ] Upload the three images from `AppStore/Screenshots/Final` in order.
- [ ] Enter App Review contact name, email, and phone number.
- [ ] Paste `AppReviewNotes.md` into App Review Information.

## Build and review

- [ ] Run `script/validate_release.sh`.
- [ ] Follow `XcodeCloudSubmission.md` to archive in Xcode Cloud with a
      supported release Xcode. Use `script/archive_app_store.sh` only if a
      supported release Xcode becomes available locally.
- [ ] In Xcode Organizer, select **Validate App** and resolve every warning.
- [ ] Upload the archive and wait for App Store Connect processing.
- [ ] Select the processed build for version 1.0.
- [ ] Test the uploaded build through TestFlight on a clean macOS account.
- [ ] Verify Automation allow, deny, and re-enable flows.
- [ ] Verify microphone changes, sleep/wake, Launch at Login, monitoring off,
      manual pause behavior, and quitting while Music is paused.
- [ ] Confirm the uploaded build contains no `com.apple.quarantine` extended
      attributes.
- [ ] Choose manual release for the first launch unless there is a reason to
      release automatically.
- [ ] Submit for review.

## Source-tree readiness

- [x] App Sandbox and Hardened Runtime enabled.
- [x] Narrow Music scripting-target entitlement used.
- [x] Automation purpose string supplied.
- [x] App icon asset catalog supplied.
- [x] Privacy manifest supplied.
- [x] Utility category and encryption declaration supplied.
- [x] Privacy policy accessible inside the app.
- [x] App Review test instructions supplied.
- [x] Storefront screenshots created and validated.
- [x] Marketing, privacy, and support site source created.
- [x] Website build and production dependency audit pass.
- [x] Reproducible release-validation and archive scripts supplied.
