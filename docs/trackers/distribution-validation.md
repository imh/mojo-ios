# Xcode validation

Parent: [App Store distribution tracker](distribution.md)

- [x] **Current local App Store Connect export**: Xcode 26.6 creates an audited privacy-packaged Apple Distribution-signed IPA with an App Store provisioning profile and `get-task-allow=false`. [gate](../../scripts/export-reference-app-store.sh)
- [x] **Current physical reference execution**: The privacy-packaged ordinary CPU, language-async, and standard Mojo Metal paths execute on the physical M1 iPad. [gate](../../scripts/test-reference-device.sh)
- [x] **Prior Apple server validation**: Xcode 26.6 accepted the pre-privacy CPU/Metal archive for App Store Connect app `6806924512`; TestFlight remained at `No Builds` and the app version remained `Prepare for Submission`.
- [x] **Current Apple server validation**: Xcode 26.6 accepts the static-framework and privacy-manifest archive through its validation-only method; the asserted validation transcript is retained locally. [gate](../../scripts/validate-reference-archive.sh)
