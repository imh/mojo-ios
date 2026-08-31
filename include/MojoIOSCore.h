#ifndef MOJO_IOS_CORE_H
#define MOJO_IOS_CORE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

int64_t mojo_ios_add(int64_t left, int64_t right);
int64_t mojo_ios_list_sum(int64_t count);
uint64_t mojo_ios_seeded_random(int64_t seed_value);
int64_t mojo_ios_argument_count(void);
void mojo_ios_parallel_fill_squares(int64_t *output, int64_t count);
int64_t mojo_ios_async_await_sum(int64_t left, int64_t right);
int64_t mojo_ios_async_parallel_sum(int64_t left, int64_t right);
int32_t mojo_ios_async_error_status(int32_t should_raise);
int32_t mojo_ios_metal_vector_add(
    const float *left,
    const float *right,
    float *output,
    int64_t count);
void mojo_ios_print_diagnostic(void);
#ifdef __cplusplus
}
#endif

#endif
