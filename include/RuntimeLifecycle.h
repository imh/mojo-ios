#ifndef MOJO_IOS_RUNTIME_LIFECYCLE_H
#define MOJO_IOS_RUNTIME_LIFECYCLE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

int64_t mojo_ios_lifecycle_library_a(int64_t *output, int64_t count);
int64_t mojo_ios_lifecycle_library_b(int64_t left, int64_t right);

int32_t mojo_ios_lifecycle_run_all(void);
int32_t mojo_ios_lifecycle_begin_suspension_probe(void);
int32_t mojo_ios_lifecycle_finish_suspension_probe(void);

#ifdef __cplusplus
}
#endif

#endif
