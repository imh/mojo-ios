# Standard library and native dependencies

Parent: [capability tracker](../CAPABILITY_LEDGER.md)

- [x] **Audited Apple surface**: Printing, random, clocks, environment, files, directory iteration, metadata, password lookup, locks, and CPU counts pass their named gates. [evidence](../IOS_TARGET_POLICY_AUDIT.md)
- [x] **Python interoperability**: Deliberately rejected at compile time for iOS; no static upstream-compatible architecture exists yet.
- [x] **Subprocess creation**: Deliberately rejected at compile time on iOS.
- [x] **Arbitrary dynamic loading**: Deliberately rejected at compile time on iOS.
- [ ] **Target-sensitive surface**: Classify the stdlib, indirect libc, and native-dependency families beyond the audited Apple slice.
- [ ] **Required Reason API audit**: Map every implemented transitive Apple API to capability scope and privacy-manifest consequences.
