#include "AsyncRT/Runtime/DeviceContextCAPI.h"

#include <assert.h>
#include <pthread.h>
#include <sched.h>
#include <stdatomic.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

enum {
  ASYNCRT_TEST_TASK_COUNT = 64,
  ASYNCRT_CPU_PARALLELISM_ATTRIBUTE = 1000,
};

uint32_t KGEN_CompilerRT_AsyncRT_ParallelismLevel(void);
typedef struct {
  void *pointer;
} CompilerRTAsyncChainRef;
void KGEN_CompilerRT_AsyncRT_InitializeChain(CompilerRTAsyncChainRef chain);
void KGEN_CompilerRT_AsyncRT_DestroyChain(CompilerRTAsyncChainRef chain);
void KGEN_CompilerRT_AsyncRT_Complete(CompilerRTAsyncChainRef chain);
void KGEN_CompilerRT_AsyncRT_Wait(CompilerRTAsyncChainRef chain);
bool KGEN_CompilerRT_AsyncRT_Wait_Timeout(CompilerRTAsyncChainRef chain,
                                         int64_t timeout_nanoseconds);
void KGEN_CompilerRT_AsyncRT_Execute(void (*resume)(int8_t *), int8_t *handle,
                                     intptr_t desired_worker_id);
void KGEN_CompilerRT_AsyncRT_AndThen(void (*resume)(int8_t *),
                                     CompilerRTAsyncChainRef chain,
                                     int8_t *handle);
void *KGEN_CompilerRT_AsyncRT_InitializeSpinWaiter(void);
void KGEN_CompilerRT_AsyncRT_SpinWaiter_Wait(void *waiter);
void KGEN_CompilerRT_AsyncRT_DestroySpinWaiter(void *waiter);
void AsyncRT_Test_resetTaskMetrics(void);
uint32_t AsyncRT_Test_activeTaskCount(void);
uint32_t AsyncRT_Test_peakTaskCount(void);

typedef struct {
  _Atomic(uint32_t) *started_task_count;
  _Atomic(uint32_t) *completed_task_count;
  _Atomic(uint32_t) *destroyed_task_count;
  _Atomic(bool) *release_tasks;
} AsyncRTDeviceContextTestTask;

typedef struct {
  CompilerRTAsyncChainRef completion_chain;
  pthread_t calling_thread;
  _Atomic(bool) *ran_on_executor_thread;
} AsyncRTLanguageTask;

typedef struct {
  CompilerRTAsyncChainRef all_continuations_chain;
  _Atomic(uint32_t) *completed_continuation_count;
  uint32_t expected_continuation_count;
} AsyncRTContinuationTask;

static void asyncrt_test_sleep_for_nanoseconds(long nanoseconds) {
  assert(nanoseconds >= 0);
  struct timespec requested_duration = {
      .tv_sec = nanoseconds / 1000000000L,
      .tv_nsec = nanoseconds % 1000000000L,
  };
  int sleep_result = nanosleep(&requested_duration, NULL);
  assert(sleep_result == 0);
}

static bool
asyncrt_test_wait_for_two_started_tasks(_Atomic(uint32_t) *started_task_count) {
  assert(started_task_count != NULL);

  enum { maximum_poll_count = 5000 };
  for (int poll_index = 0; poll_index < maximum_poll_count; ++poll_index) {
    if (atomic_load_explicit(started_task_count, memory_order_acquire) >= 2)
      return true;
    asyncrt_test_sleep_for_nanoseconds(1000000L);
  }
  return false;
}

static bool asyncrt_test_wait_for_executor_idle(void) {
  enum { maximum_poll_count = 5000 };
  for (int poll_index = 0; poll_index < maximum_poll_count; ++poll_index) {
    if (AsyncRT_Test_activeTaskCount() == 0)
      return true;
    asyncrt_test_sleep_for_nanoseconds(1000000L);
  }
  return false;
}

static void asyncrt_test_resume_coroutine(void *untyped_task) {
  AsyncRTDeviceContextTestTask *task = untyped_task;
  assert(task != NULL);

  atomic_fetch_add_explicit(task->started_task_count, 1, memory_order_acq_rel);
  while (!atomic_load_explicit(task->release_tasks, memory_order_acquire))
    sched_yield();

  uint32_t completed_task_count =
      atomic_fetch_add_explicit(task->completed_task_count, 1,
                                memory_order_acq_rel) +
      1;
  assert(completed_task_count <= ASYNCRT_TEST_TASK_COUNT);
}

static void asyncrt_test_destroy_coroutine(void *untyped_task) {
  AsyncRTDeviceContextTestTask *task = untyped_task;
  assert(task != NULL);
  uint32_t destroyed_task_count =
      atomic_fetch_add_explicit(task->destroyed_task_count, 1,
                                memory_order_acq_rel) +
      1;
  assert(destroyed_task_count <= ASYNCRT_TEST_TASK_COUNT);
}

static void asyncrt_test_language_task_resume(int8_t *untyped_task) {
  AsyncRTLanguageTask *task = (AsyncRTLanguageTask *)untyped_task;
  assert(task != NULL);
  assert(!pthread_equal(pthread_self(), task->calling_thread));
  atomic_store_explicit(task->ran_on_executor_thread, true,
                        memory_order_release);
  KGEN_CompilerRT_AsyncRT_Complete(task->completion_chain);
}

static void asyncrt_test_continuation_resume(int8_t *untyped_task) {
  AsyncRTContinuationTask *task = (AsyncRTContinuationTask *)untyped_task;
  assert(task != NULL);
  uint32_t completed_count = atomic_fetch_add_explicit(
                                 task->completed_continuation_count, 1,
                                 memory_order_acq_rel) +
                             1;
  assert(completed_count <= task->expected_continuation_count);
  if (completed_count == task->expected_continuation_count)
    KGEN_CompilerRT_AsyncRT_Complete(task->all_continuations_chain);
}

static void asyncrt_test_language_async_abi(void) {
  void *completion_storage = NULL;
  CompilerRTAsyncChainRef completion_chain = {
      .pointer = &completion_storage,
  };
  KGEN_CompilerRT_AsyncRT_InitializeChain(completion_chain);
  assert(completion_storage != NULL);
  assert(!KGEN_CompilerRT_AsyncRT_Wait_Timeout(completion_chain, 1000000));

  _Atomic(bool) ran_on_executor_thread = false;
  AsyncRTLanguageTask language_task = {
      .completion_chain = completion_chain,
      .calling_thread = pthread_self(),
      .ran_on_executor_thread = &ran_on_executor_thread,
  };
  KGEN_CompilerRT_AsyncRT_Execute(asyncrt_test_language_task_resume,
                                  (int8_t *)&language_task, -1);
  KGEN_CompilerRT_AsyncRT_Wait(completion_chain);
  assert(atomic_load_explicit(&ran_on_executor_thread, memory_order_acquire));
  assert(KGEN_CompilerRT_AsyncRT_Wait_Timeout(completion_chain, 0));
  KGEN_CompilerRT_AsyncRT_DestroyChain(completion_chain);
  assert(completion_storage == NULL);

  enum { continuation_count = 64 };
  void *prerequisite_storage = NULL;
  void *all_continuations_storage = NULL;
  CompilerRTAsyncChainRef prerequisite_chain = {
      .pointer = &prerequisite_storage,
  };
  CompilerRTAsyncChainRef all_continuations_chain = {
      .pointer = &all_continuations_storage,
  };
  KGEN_CompilerRT_AsyncRT_InitializeChain(prerequisite_chain);
  KGEN_CompilerRT_AsyncRT_InitializeChain(all_continuations_chain);
  _Atomic(uint32_t) completed_continuation_count = 0;
  AsyncRTContinuationTask continuation_tasks[continuation_count];
  for (uint32_t task_index = 0; task_index < continuation_count; ++task_index) {
    continuation_tasks[task_index] = (AsyncRTContinuationTask){
        .all_continuations_chain = all_continuations_chain,
        .completed_continuation_count = &completed_continuation_count,
        .expected_continuation_count = continuation_count,
    };
    KGEN_CompilerRT_AsyncRT_AndThen(
        asyncrt_test_continuation_resume, prerequisite_chain,
        (int8_t *)&continuation_tasks[task_index]);
  }
  KGEN_CompilerRT_AsyncRT_Complete(prerequisite_chain);
  KGEN_CompilerRT_AsyncRT_Wait(all_continuations_chain);
  assert(atomic_load_explicit(&completed_continuation_count,
                              memory_order_acquire) == continuation_count);
  KGEN_CompilerRT_AsyncRT_DestroyChain(prerequisite_chain);
  KGEN_CompilerRT_AsyncRT_DestroyChain(all_continuations_chain);
  assert(prerequisite_storage == NULL);
  assert(all_continuations_storage == NULL);
}

static void asyncrt_test_coreai_device_context(void) {
  void *context = NULL;
  const char *error_message =
      AsyncRT_DeviceContext_create(&context, "coreai", 0);
  assert(error_message != NULL);
  assert(strstr(error_message, "Core AI") != NULL);
  assert(strstr(error_message, "not implemented") != NULL);
  AsyncRT_DeviceContext_strfree(error_message);
  assert(context == NULL);
}

int main(void) {
  assert(KGEN_CompilerRT_AsyncRT_ParallelismLevel() >= 2);
  asyncrt_test_language_async_abi();
  asyncrt_test_coreai_device_context();

  void *context = NULL;
  const char *error_message = AsyncRT_DeviceContext_create(&context, "cpu", 0);
  assert(error_message == NULL);
  assert(context != NULL);

  AsyncRTStringRef api = {0};
  AsyncRT_DeviceContext_deviceApi(&api, context);
  assert(api.data != NULL);
  assert(api.length == 3);
  assert(memcmp(api.data, "cpu", 3) == 0);

  int32_t parallelism_level = 0;
  error_message = AsyncRT_DeviceContext_getAttribute(
      &parallelism_level, context, ASYNCRT_CPU_PARALLELISM_ATTRIBUTE);
  assert(error_message == NULL);
  assert(parallelism_level >= 2);

  int32_t unsupported_attribute_result = 0;
  error_message = AsyncRT_DeviceContext_getAttribute(
      &unsupported_attribute_result, context, -1);
  assert(error_message != NULL);
  AsyncRT_DeviceContext_strfree(error_message);

  AsyncRT_DeviceContext_retain(context);
  AsyncRT_DeviceContext_release(context);

  void *spin_waiter = KGEN_CompilerRT_AsyncRT_InitializeSpinWaiter();
  assert(spin_waiter != NULL);
  KGEN_CompilerRT_AsyncRT_SpinWaiter_Wait(spin_waiter);
  KGEN_CompilerRT_AsyncRT_DestroySpinWaiter(spin_waiter);

  AsyncRT_Test_resetTaskMetrics();
  _Atomic(uint32_t) started_task_count = 0;
  _Atomic(uint32_t) completed_task_count = 0;
  _Atomic(uint32_t) destroyed_task_count = 0;
  _Atomic(bool) release_tasks = false;
  AsyncRTDeviceContextTestTask tasks[ASYNCRT_TEST_TASK_COUNT];
  void *handles[ASYNCRT_TEST_TASK_COUNT];

  for (int task_index = 0; task_index < ASYNCRT_TEST_TASK_COUNT; ++task_index) {
    tasks[task_index] = (AsyncRTDeviceContextTestTask){
        .started_task_count = &started_task_count,
        .completed_task_count = &completed_task_count,
        .destroyed_task_count = &destroyed_task_count,
        .release_tasks = &release_tasks,
    };
    handles[task_index] = &tasks[task_index];
  }

  error_message = AsyncRT_DeviceContext_enqueueHostFunctionRange(
      context, asyncrt_test_resume_coroutine, asyncrt_test_destroy_coroutine,
      handles, ASYNCRT_TEST_TASK_COUNT);
  assert(error_message == NULL);
  assert(asyncrt_test_wait_for_two_started_tasks(&started_task_count) &&
         "the DeviceContext backend did not overlap two coroutines");
  atomic_store_explicit(&release_tasks, true, memory_order_release);

  error_message = AsyncRT_DeviceContext_synchronize(context);
  assert(error_message == NULL);
  assert(atomic_load_explicit(&completed_task_count, memory_order_acquire) ==
         ASYNCRT_TEST_TASK_COUNT);
  assert(atomic_load_explicit(&destroyed_task_count, memory_order_acquire) ==
         ASYNCRT_TEST_TASK_COUNT);
  assert(asyncrt_test_wait_for_executor_idle());
  assert(AsyncRT_Test_peakTaskCount() > 1);

  AsyncRT_DeviceContext_release(context);
  puts("MOJO_IOS_ASYNCRT_HOST_PASS language_async=execute-chain-andthen-timeout "
       "coreai_context=not-implemented "
       "device_context_tasks=64 destroyed_coroutines=64 "
       "peak_concurrency_gt=1");
  return 0;
}
