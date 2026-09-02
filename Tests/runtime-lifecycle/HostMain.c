#include "RuntimeLifecycle.h"

#include <assert.h>
#include <stdio.h>

int main(void) {
  assert(mojo_ios_lifecycle_run_all() == 0);
  assert(mojo_ios_lifecycle_begin_suspension_probe() == 0);
  assert(mojo_ios_lifecycle_finish_suspension_probe() == 0);
  puts("MOJO_IOS_RUNTIME_LIFECYCLE_HOST_PASS");
  return 0;
}
