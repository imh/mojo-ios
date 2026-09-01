#include "CPUConformance.h"

#include <assert.h>
#include <stdio.h>

int main(void) {
  const int64_t family_count = mojo_ios_conformance_family_count();
  assert(family_count > 0);
  assert(mojo_ios_conformance_run_all() == 0);
  printf("CPU_CONFORMANCE_HOST_PASS families=%lld\n", (long long)family_count);
  return 0;
}
