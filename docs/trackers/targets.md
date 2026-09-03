# Targets and hardware

Parent: [capability tracker](../CAPABILITY_LEDGER.md)

## Proved lanes

- [x] **Current physical iPad feasibility**: CPU, parallel, async, and useful Metal probes execute on the current M1 iPad.
- [x] **ARM64 Simulator feasibility**: CPU and Metal probes execute on ARM64 iPhone and iPad Simulators; Core AI remains explicitly unavailable.
- [x] **Current M-series Metal lane**: The useful Metal slice executes on a physical M1 iPad.
- [x] **Current Core AI preview lane**: The public Swift probe executes on the M1 iPad with iPadOS 27 beta and a matching specialization.

## Enablement decision

- [ ] **Base minimum and latest OS lanes**: The product minimum and current stable/latest policy remain undefined; iOS 15 is feasibility only.

## Verification backlog

- [ ] **Physical A-series iPhone lane**: Required before a broad iOS CPU/Metal hardware claim.
- [ ] **Additional Core AI hardware lane**: Required before broadening the current single-device preview evidence.
