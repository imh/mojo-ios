#include <inttypes.h>
#include <stdint.h>
#include <stdio.h>

extern int64_t mojo_ios_conformance_vectorized_memory(void);

int main(void) {
  const int64_t result = mojo_ios_conformance_vectorized_memory();
  if (result != INT64_C(42)) {
    fprintf(stderr,
            "CPU numeric ASan failure: expected=42 actual=%" PRId64 "\n",
            result);
    return 1;
  }
  puts("CPU_NUMERICS_ASAN_PASS mojo_instrumented=yes masked_tail=yes");
  return 0;
}
