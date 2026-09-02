#include <assert.h>
#include <stddef.h>
#include <stdint.h>

typedef int64_t (*MojoIOSLifecycleCallback)(int64_t value, int64_t context);

int64_t
mojo_ios_lifecycle_invoke_callback(MojoIOSLifecycleCallback callback,
                                   int64_t value, int64_t context) {
  assert(callback != NULL);
  return callback(value, context);
}
