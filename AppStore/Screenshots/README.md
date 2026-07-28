# App Store screenshots

`Final/` contains the upload-ready English screenshots. Upload them in filename
order.

`Source/` contains the genuine app-window captures used in the compositions.
The settings images intentionally show both the primary controls and the lower
privacy/Automation section.

To regenerate the final 2560 × 1600 JPEGs after replacing source captures:

```bash
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcrun swift script/generate_app_store_screenshots.swift
```

Validate every output before uploading:

```bash
for image in AppStore/Screenshots/Final/*.jpg; do
  sips -g pixelWidth -g pixelHeight -g hasAlpha "$image"
done
```
