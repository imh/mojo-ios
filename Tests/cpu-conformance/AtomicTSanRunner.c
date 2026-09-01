#include <assert.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>

extern int64_t mojo_ios_conformance_atomic_concurrency(void);

enum { kThreadCount = 8 };

static atomic_int failure_count;

static void *run_atomic_conformance(void *unused) {
  (void)unused;
  if (mojo_ios_conformance_atomic_concurrency() != INT64_C(42)) {
    atomic_fetch_add_explicit(&failure_count, 1, memory_order_relaxed);
  }
  return NULL;
}

int main(void) {
  pthread_t threads[kThreadCount];
  atomic_init(&failure_count, 0);
  for (size_t index = 0; index < kThreadCount; ++index) {
    assert(pthread_create(&threads[index], NULL, run_atomic_conformance,
                          NULL) == 0);
  }
  for (size_t index = 0; index < kThreadCount; ++index) {
    assert(pthread_join(threads[index], NULL) == 0);
  }
  assert(atomic_load_explicit(&failure_count, memory_order_relaxed) == 0);
  puts("CPU_STATE_TSAN_PASS mojo_instrumented=yes foreign_threads=8");
  return 0;
}
