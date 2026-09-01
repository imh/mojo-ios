#include "CPUConformance.h"

#include <assert.h>
#include <stddef.h>

int64_t mojo_ios_conformance_c_add(int64_t left, int64_t right) {
  return left + right;
}

int64_t mojo_ios_conformance_invoke_callback(
    MojoIOSConformanceCallback callback, int64_t value, int64_t context) {
  assert(callback != NULL);
  return callback(value, context);
}
