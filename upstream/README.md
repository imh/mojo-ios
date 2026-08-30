# Upstream compiler pin

`REVISION` pins the exact `modular/modular` commit used by the source-compiler
gate. `scripts/checkout-upstream.sh` materializes that revision under the
ignored `.work/modular` directory.

The gate builds `//KGEN/tools/mojo:mojo`, the compiler executable used for
ahead-of-time library compilation. The `mojo-full` convenience target also
bundles LLDB and debugger helpers; those are intentionally outside this iOS
library toolchain boundary. Standard-library and MAX sources are supplied
explicitly to the source-built compiler and compiled on demand by the probes.

The checkout URL defaults to the official repository. Set
`MOJO_UPSTREAM_URL` to a fork URL once compiler changes are required. Changes
belong in the fork or as reviewable patches under `patches/modular`; generated
or unrecorded edits in `.work/modular` are not project state.

`scripts/apply-upstream-patches.sh` applies the reviewed stack idempotently.
`pixi run build-source-core` then builds both XCFramework variants with the
source-built compiler and source stdlib rather than the packaged toolchain.

At this revision the thin compiler reports `1.1.0.dev0` with a placeholder
commit label. Reproducibility therefore comes from the full hash in `REVISION`,
not from the compiler's human-readable version string. Mojo 1.0 remains the
separately locked packaged baseline.
