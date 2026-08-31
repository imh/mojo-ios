# Xcode validation

Parent: [App Store distribution tracker](distribution.md)

- [x] **Local App Store Connect export**: Xcode 26.6 creates an audited Apple Distribution-signed IPA with an App Store provisioning profile and `get-task-allow=false`. [gate](../../scripts/export-reference-app-store.sh)
- [x] **Physical reference execution**: The archived ordinary CPU, language-async, and standard Mojo Metal paths execute on the physical M1 iPad. [gate](../../scripts/test-reference-device.sh)
- [x] **Apple server validation**: Xcode 26.6 server validation accepts the signed CPU/Metal reference archive for App Store Connect app `6806924512`; TestFlight remains at `No Builds` and the app version remains `Prepare for Submission`. [gate](../../scripts/validate-reference-archive.sh)
