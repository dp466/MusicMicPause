# App Store Submission Checklist

## Required developer-account work

- [ ] Set the Distribution signing team in Xcode.
- [ ] Confirm the final bundle identifier and create/match the App Store Connect
      app record.
- [ ] Replace the working version/build values if needed; increment the build
      number for every upload.
- [ ] Host `docs/privacy.html` and `docs/support.html` on public HTTPS URLs.
- [ ] Enter those URLs in App Store Connect.
- [ ] Complete App Privacy as **Data Not Collected**, provided the implementation
      remains unchanged.
- [ ] Review and enter the draft in `Metadata.md`.
- [ ] Capture the clean Mac screenshots described in `Metadata.md`.
- [ ] Paste the contents of `AppReviewNotes.md` into App Review Information.
- [ ] Archive with the current stable, App Store-supported Xcode release.
- [ ] Run **Validate App**, resolve every warning, then upload.
- [ ] Test the uploaded build with TestFlight on a clean macOS user account,
      including Automation denial/re-enable, device switching, sleep/wake,
      Launch at Login, disable, and quit while Music is paused.

## Current source-tree readiness

- [x] App Sandbox and Hardened Runtime enabled.
- [x] Narrow Music scripting target entitlement used.
- [x] Automation purpose string supplied.
- [x] App icon asset catalog supplied.
- [x] Privacy manifest supplied.
- [x] Utility category and encryption declaration supplied.
- [x] Privacy policy accessible inside the app.
- [x] App Review test instructions supplied.
