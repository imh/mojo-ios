#include "CPUConformance.h"

#include <assert.h>
#include <stdio.h>

int main(void) {
  assert(mojo_ios_conformance_ownership() == 2111);
  assert(mojo_ios_conformance_generics() == 42);
  assert(mojo_ios_conformance_traits() == 42);
  assert(mojo_ios_conformance_errors() == 42);
  assert(mojo_ios_conformance_ffi() == 42);
  assert(mojo_ios_conformance_callbacks() == 42);
  puts("CPU_CONFORMANCE_HOST_PASS families=6");
  return 0;
}
