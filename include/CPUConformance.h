#ifndef MOJO_IOS_CPU_CONFORMANCE_H
#define MOJO_IOS_CPU_CONFORMANCE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef int64_t (*MojoIOSConformanceCallback)(int64_t value, int64_t context);

int64_t mojo_ios_conformance_family_count(void);
int64_t mojo_ios_conformance_run_all(void);

int64_t mojo_ios_conformance_c_add(int64_t left, int64_t right);
int64_t
mojo_ios_conformance_invoke_callback(MojoIOSConformanceCallback callback,
                                     int64_t value, int64_t context);

#ifdef __cplusplus
}
#endif

#endif
