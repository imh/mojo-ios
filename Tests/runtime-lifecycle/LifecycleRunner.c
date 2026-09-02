#include "RuntimeLifecycle.h"

#include "AsyncRT/Runtime/DeviceContextCAPI.h"

#include <assert.h>
#include <pthread.h>
#include <sched.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#ifndef MOJO_IOS_LIFECYCLE_THREAD_COUNT
#define MOJO_IOS_LIFECYCLE_THREAD_COUNT 8
#endif
#ifndef MOJO_IOS_LIFECYCLE_CALL_COUNT
#define MOJO_IOS_LIFECYCLE_CALL_COUNT 16
#endif
#ifndef MOJO_IOS_LIFECYCLE_ELEMENT_COUNT
#define MOJO_IOS_LIFECYCLE_ELEMENT_COUNT 64
#endif
#define MOJO_IOS_LIFECYCLE_SUSPENSION_TASK_COUNT 2

typedef struct {
  const char *data;
  size_t length;
} CompilerRTStringRef;

typedef void *(*CompilerRTGlobalInitializeFunction)(void);
typedef void (*CompilerRTGlobalDestroyFunction)(void *);

typedef struct {
  void *pointer;
} CompilerRTAsyncRTRuntimeRef;

bool KGEN_CompilerRT_Initialize(void);
void *KGEN_CompilerRT_GetOrCreateGlobal(
    CompilerRTStringRef name,
    CompilerRTGlobalInitializeFunction initialize_function,
    CompilerRTGlobalDestroyFunction destroy_function);
void KGEN_CompilerRT_DestroyGlobals(void);
CompilerRTAsyncRTRuntimeRef KGEN_CompilerRT_AsyncRT_GetCurrentCPUDevice(void);

typedef struct {
  _Atomic(bool) failed;
  void *runtime_pointer;
  int thread_index;
} MojoIOSLifecycleThreadState;

typedef struct {
  _Atomic(uint32_t) started_task_count;
  _Atomic(uint32_t) completed_task_count;
  _Atomic(uint32_t) destroyed_task_count;
  _Atomic(bool) release_tasks;
  void *context;
  bool active;
} MojoIOSLifecycleSuspensionState;

static _Atomic(uint32_t) lifecycle_global_initialize_count;
static _Atomic(uint32_t) lifecycle_global_destroy_count;
static MojoIOSLifecycleSuspensionState lifecycle_suspension_state;
static pthread_mutex_t lifecycle_suspension_mutex = PTHREAD_MUTEX_INITIALIZER;

static void lifecycle_sleep_for_nanoseconds(long nanoseconds) {
  assert(nanoseconds >= 0);
  struct timespec requested_duration = {
      .tv_sec = nanoseconds / 1000000000L,
      .tv_nsec = nanoseconds % 1000000000L,
  };
  int sleep_result = nanosleep(&requested_duration, NULL);
  assert(sleep_result == 0);
}

static int64_t lifecycle_library_a_expected(int64_t count) {
  assert(count > 0);
  int64_t owned_sum = count * (count + 1) / 2;
  int64_t square_sum = (count - 1) * count * (2 * count - 1) / 6;
  return owned_sum + square_sum;
}

static bool lifecycle_run_library_pair(int thread_index) {
  int64_t output[MOJO_IOS_LIFECYCLE_ELEMENT_COUNT] = {0};
  int64_t library_a_result = mojo_ios_lifecycle_library_a(
      output, MOJO_IOS_LIFECYCLE_ELEMENT_COUNT);
  if (library_a_result !=
      lifecycle_library_a_expected(MOJO_IOS_LIFECYCLE_ELEMENT_COUNT))
    return false;
  for (int64_t index = 0; index < MOJO_IOS_LIFECYCLE_ELEMENT_COUNT; ++index) {
    if (output[index] != index * index)
      return false;
  }

  int64_t left = thread_index;
  int64_t library_b_result =
      mojo_ios_lifecycle_library_b(left, INT64_C(39) - left);
  return library_b_result == 87;
}

static void *lifecycle_thread_main(void *untyped_state) {
  MojoIOSLifecycleThreadState *state = untyped_state;
  assert(state != NULL);
  for (int call_index = 0; call_index < MOJO_IOS_LIFECYCLE_CALL_COUNT;
       ++call_index) {
    if (!lifecycle_run_library_pair(state->thread_index)) {
      atomic_store_explicit(&state->failed, true, memory_order_release);
      return NULL;
    }
  }
  state->runtime_pointer =
      KGEN_CompilerRT_AsyncRT_GetCurrentCPUDevice().pointer;
  if (state->runtime_pointer == NULL)
    atomic_store_explicit(&state->failed, true, memory_order_release);
  return NULL;
}

static void *lifecycle_global_initialize(void) {
  uint32_t initialization_index = atomic_fetch_add_explicit(
                                      &lifecycle_global_initialize_count, 1,
                                      memory_order_acq_rel) +
                                  1;
  uint32_t *value = malloc(sizeof(*value));
  assert(value != NULL);
  *value = initialization_index;
  return value;
}

static void lifecycle_global_destroy(void *untyped_value) {
  assert(untyped_value != NULL);
  free(untyped_value);
  atomic_fetch_add_explicit(&lifecycle_global_destroy_count, 1,
                            memory_order_acq_rel);
}

typedef struct {
  void *value;
} MojoIOSLifecycleGlobalThreadState;

static void *lifecycle_global_thread_main(void *untyped_state) {
  static const char global_name_data[] = "MojoIOS.Lifecycle.SharedGlobal";
  CompilerRTStringRef global_name = {
      .data = global_name_data,
      .length = sizeof(global_name_data) - 1,
  };
  MojoIOSLifecycleGlobalThreadState *state = untyped_state;
  assert(state != NULL);
  state->value = KGEN_CompilerRT_GetOrCreateGlobal(
      global_name, lifecycle_global_initialize, lifecycle_global_destroy);
  assert(state->value != NULL);
  return NULL;
}

static bool lifecycle_test_global_contention_and_destruction(void) {
  atomic_store_explicit(&lifecycle_global_initialize_count, 0,
                        memory_order_release);
  atomic_store_explicit(&lifecycle_global_destroy_count, 0,
                        memory_order_release);

  pthread_t threads[MOJO_IOS_LIFECYCLE_THREAD_COUNT];
  MojoIOSLifecycleGlobalThreadState states[MOJO_IOS_LIFECYCLE_THREAD_COUNT] = {
      0};
  for (int thread_index = 0; thread_index < MOJO_IOS_LIFECYCLE_THREAD_COUNT;
       ++thread_index) {
    int create_result = pthread_create(&threads[thread_index], NULL,
                                       lifecycle_global_thread_main,
                                       &states[thread_index]);
    assert(create_result == 0);
  }
  for (int thread_index = 0; thread_index < MOJO_IOS_LIFECYCLE_THREAD_COUNT;
       ++thread_index) {
    int join_result = pthread_join(threads[thread_index], NULL);
    assert(join_result == 0);
    if (states[thread_index].value != states[0].value)
      return false;
  }

  uint32_t initialize_count = atomic_load_explicit(
      &lifecycle_global_initialize_count, memory_order_acquire);
  uint32_t destroy_count = atomic_load_explicit(
      &lifecycle_global_destroy_count, memory_order_acquire);
  if (initialize_count == 0 || destroy_count + 1 != initialize_count)
    return false;

  KGEN_CompilerRT_DestroyGlobals();
  destroy_count = atomic_load_explicit(&lifecycle_global_destroy_count,
                                       memory_order_acquire);
  if (destroy_count != initialize_count ||
      KGEN_CompilerRT_AsyncRT_GetCurrentCPUDevice().pointer != NULL)
    return false;

  static const char global_name_data[] = "MojoIOS.Lifecycle.SharedGlobal";
  CompilerRTStringRef global_name = {
      .data = global_name_data,
      .length = sizeof(global_name_data) - 1,
  };
  void *recreated_value = KGEN_CompilerRT_GetOrCreateGlobal(
      global_name, lifecycle_global_initialize, lifecycle_global_destroy);
  if (recreated_value == NULL)
    return false;
  uint32_t recreated_initialize_count = atomic_load_explicit(
      &lifecycle_global_initialize_count, memory_order_acquire);
  if (recreated_initialize_count != initialize_count + 1)
    return false;

  KGEN_CompilerRT_DestroyGlobals();
  return atomic_load_explicit(&lifecycle_global_destroy_count,
                              memory_order_acquire) ==
             recreated_initialize_count &&
         KGEN_CompilerRT_AsyncRT_GetCurrentCPUDevice().pointer == NULL;
}

static bool lifecycle_test_context_cycles(void) {
  for (int cycle_index = 0; cycle_index < 64; ++cycle_index) {
    void *context = NULL;
    const char *error_message =
        AsyncRT_DeviceContext_create(&context, "cpu", 0);
    if (error_message != NULL || context == NULL) {
      AsyncRT_DeviceContext_strfree(error_message);
      return false;
    }
    AsyncRT_DeviceContext_retain(context);
    AsyncRT_DeviceContext_release(context);
    error_message = AsyncRT_DeviceContext_synchronize(context);
    if (error_message != NULL) {
      AsyncRT_DeviceContext_strfree(error_message);
      AsyncRT_DeviceContext_release(context);
      return false;
    }
    AsyncRT_DeviceContext_release(context);
  }
  return true;
}

static void lifecycle_suspension_task_resume(void *untyped_state) {
  MojoIOSLifecycleSuspensionState *state = untyped_state;
  assert(state != NULL);
  atomic_fetch_add_explicit(&state->started_task_count, 1,
                            memory_order_acq_rel);
  while (!atomic_load_explicit(&state->release_tasks, memory_order_acquire))
    sched_yield();
  atomic_fetch_add_explicit(&state->completed_task_count, 1,
                            memory_order_acq_rel);
}

static void lifecycle_suspension_task_destroy(void *untyped_state) {
  MojoIOSLifecycleSuspensionState *state = untyped_state;
  assert(state != NULL);
  atomic_fetch_add_explicit(&state->destroyed_task_count, 1,
                            memory_order_acq_rel);
}

int32_t mojo_ios_lifecycle_run_all(void) {
  assert(KGEN_CompilerRT_Initialize());
  assert(KGEN_CompilerRT_Initialize());

  if (KGEN_CompilerRT_AsyncRT_GetCurrentCPUDevice().pointer != NULL)
    KGEN_CompilerRT_DestroyGlobals();
  if (KGEN_CompilerRT_AsyncRT_GetCurrentCPUDevice().pointer != NULL)
    return 1;

  pthread_t threads[MOJO_IOS_LIFECYCLE_THREAD_COUNT];
  MojoIOSLifecycleThreadState states[MOJO_IOS_LIFECYCLE_THREAD_COUNT];
  memset(states, 0, sizeof(states));
  for (int thread_index = 0; thread_index < MOJO_IOS_LIFECYCLE_THREAD_COUNT;
       ++thread_index) {
    atomic_init(&states[thread_index].failed, false);
    states[thread_index].thread_index = thread_index;
    int create_result = pthread_create(&threads[thread_index], NULL,
                                       lifecycle_thread_main,
                                       &states[thread_index]);
    assert(create_result == 0);
  }
  for (int thread_index = 0; thread_index < MOJO_IOS_LIFECYCLE_THREAD_COUNT;
       ++thread_index) {
    int join_result = pthread_join(threads[thread_index], NULL);
    assert(join_result == 0);
    if (atomic_load_explicit(&states[thread_index].failed,
                             memory_order_acquire))
      return 2;
    if (states[thread_index].runtime_pointer != states[0].runtime_pointer)
      return 3;
  }

  if (!lifecycle_test_context_cycles())
    return 4;
  if (!lifecycle_test_global_contention_and_destruction())
    return 5;

  if (!lifecycle_run_library_pair(0))
    return 6;
  if (KGEN_CompilerRT_AsyncRT_GetCurrentCPUDevice().pointer == NULL)
    return 7;
  return 0;
}

int32_t mojo_ios_lifecycle_begin_suspension_probe(void) {
  int lock_result = pthread_mutex_lock(&lifecycle_suspension_mutex);
  assert(lock_result == 0);
  assert(!lifecycle_suspension_state.active &&
         "only one runtime suspension probe may be active");
  memset(&lifecycle_suspension_state, 0,
         sizeof(lifecycle_suspension_state));
  atomic_init(&lifecycle_suspension_state.started_task_count, 0);
  atomic_init(&lifecycle_suspension_state.completed_task_count, 0);
  atomic_init(&lifecycle_suspension_state.destroyed_task_count, 0);
  atomic_init(&lifecycle_suspension_state.release_tasks, false);

  const char *error_message = AsyncRT_DeviceContext_create(
      &lifecycle_suspension_state.context, "cpu", 0);
  if (error_message != NULL) {
    AsyncRT_DeviceContext_strfree(error_message);
    int unlock_result = pthread_mutex_unlock(&lifecycle_suspension_mutex);
    assert(unlock_result == 0);
    return 1;
  }
  lifecycle_suspension_state.active = true;
  void *handles[MOJO_IOS_LIFECYCLE_SUSPENSION_TASK_COUNT] = {
      &lifecycle_suspension_state,
      &lifecycle_suspension_state,
  };
  error_message = AsyncRT_DeviceContext_enqueueHostFunctionRange(
      lifecycle_suspension_state.context, lifecycle_suspension_task_resume,
      lifecycle_suspension_task_destroy, handles,
      MOJO_IOS_LIFECYCLE_SUSPENSION_TASK_COUNT);
  assert(error_message == NULL);
  int unlock_result = pthread_mutex_unlock(&lifecycle_suspension_mutex);
  assert(unlock_result == 0);

  for (int poll_index = 0; poll_index < 5000; ++poll_index) {
    if (atomic_load_explicit(&lifecycle_suspension_state.started_task_count,
                             memory_order_acquire) ==
        MOJO_IOS_LIFECYCLE_SUSPENSION_TASK_COUNT)
      return 0;
    lifecycle_sleep_for_nanoseconds(1000000L);
  }
  return 2;
}

int32_t mojo_ios_lifecycle_finish_suspension_probe(void) {
  int lock_result = pthread_mutex_lock(&lifecycle_suspension_mutex);
  assert(lock_result == 0);
  assert(lifecycle_suspension_state.active &&
         "the runtime suspension probe must be started before it is finished");
  atomic_store_explicit(&lifecycle_suspension_state.release_tasks, true,
                        memory_order_release);
  const char *error_message = AsyncRT_DeviceContext_synchronize(
      lifecycle_suspension_state.context);
  if (error_message != NULL) {
    AsyncRT_DeviceContext_strfree(error_message);
    int unlock_result = pthread_mutex_unlock(&lifecycle_suspension_mutex);
    assert(unlock_result == 0);
    return 1;
  }
  bool counts_match =
      atomic_load_explicit(&lifecycle_suspension_state.completed_task_count,
                           memory_order_acquire) ==
          MOJO_IOS_LIFECYCLE_SUSPENSION_TASK_COUNT &&
      atomic_load_explicit(&lifecycle_suspension_state.destroyed_task_count,
                           memory_order_acquire) ==
          MOJO_IOS_LIFECYCLE_SUSPENSION_TASK_COUNT;
  AsyncRT_DeviceContext_release(lifecycle_suspension_state.context);
  lifecycle_suspension_state.context = NULL;
  lifecycle_suspension_state.active = false;
  int unlock_result = pthread_mutex_unlock(&lifecycle_suspension_mutex);
  assert(unlock_result == 0);
  return counts_match ? 0 : 2;
}
