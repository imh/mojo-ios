#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
  const char *data;
  size_t length;
} CompilerRTStringRef;

typedef struct {
  CompilerRTStringRef *arguments;
  size_t length;
} CompilerRTArgumentList;

typedef void *(*CompilerRTGlobalInitializeFunction)(void);
typedef void (*CompilerRTGlobalDestroyFunction)(void *);

typedef struct {
  void *pointer;
} CompilerRTAsyncRTRuntimeRef;

bool KGEN_CompilerRT_Initialize(void);
void *KGEN_CompilerRT_AlignedAlloc(ptrdiff_t alignment, ptrdiff_t size);
void KGEN_CompilerRT_AlignedFree(void *pointer);
size_t KGEN_CompilerRT_NumPhysicalCores(void);
size_t KGEN_CompilerRT_NumLogicalCores(void);
size_t KGEN_CompilerRT_NumPerformanceCores(void);
void KGEN_CompilerRT_GetArgV(CompilerRTArgumentList *result);
void KGEN_CompilerRT_SetArgV(int argument_count, char **arguments);
void *KGEN_CompilerRT_GetOrCreateGlobal(
    CompilerRTStringRef name,
    CompilerRTGlobalInitializeFunction initialize_function,
    CompilerRTGlobalDestroyFunction destroy_function);
void *KGEN_CompilerRT_GetOrCreateGlobalIndexed(
    size_t index, CompilerRTGlobalInitializeFunction initialize_function,
    CompilerRTGlobalDestroyFunction destroy_function);
void KGEN_CompilerRT_DestroyGlobals(void);
CompilerRTAsyncRTRuntimeRef KGEN_CompilerRT_AsyncRT_GetCurrentCPUDevice(void);
CompilerRTAsyncRTRuntimeRef KGEN_CompilerRT_AsyncRT_GetOrCreateCPUDevice(void);
void KGEN_CompilerRT_AsyncRT_ReleaseCPUDevice(
    CompilerRTAsyncRTRuntimeRef runtime);

static uint32_t destroyed_value_count;

static void *create_test_value(void) {
  uint32_t *value = malloc(sizeof(*value));
  assert(value != NULL);
  *value = 42;
  return value;
}

static void destroy_test_value(void *untyped_value) {
  uint32_t *value = untyped_value;
  assert(value != NULL);
  assert(*value == 42);
  ++destroyed_value_count;
  free(value);
}

int main(void) {
  assert(KGEN_CompilerRT_Initialize());
  assert(KGEN_CompilerRT_Initialize());
  assert(KGEN_CompilerRT_NumPhysicalCores() >= 1);
  assert(KGEN_CompilerRT_NumLogicalCores() >= 1);
  assert(KGEN_CompilerRT_NumPerformanceCores() >= 1);

  assert(KGEN_CompilerRT_AsyncRT_GetCurrentCPUDevice().pointer == NULL);
  CompilerRTAsyncRTRuntimeRef first_runtime =
      KGEN_CompilerRT_AsyncRT_GetOrCreateCPUDevice();
  assert(first_runtime.pointer != NULL);
  assert(KGEN_CompilerRT_AsyncRT_GetCurrentCPUDevice().pointer ==
         first_runtime.pointer);
  CompilerRTAsyncRTRuntimeRef second_runtime =
      KGEN_CompilerRT_AsyncRT_GetOrCreateCPUDevice();
  assert(second_runtime.pointer == first_runtime.pointer);
  KGEN_CompilerRT_AsyncRT_ReleaseCPUDevice(second_runtime);
  assert(KGEN_CompilerRT_AsyncRT_GetCurrentCPUDevice().pointer ==
         first_runtime.pointer);
  KGEN_CompilerRT_AsyncRT_ReleaseCPUDevice(first_runtime);
  assert(KGEN_CompilerRT_AsyncRT_GetCurrentCPUDevice().pointer == NULL);

  void *allocation = KGEN_CompilerRT_AlignedAlloc(64, 128);
  assert(allocation != NULL);
  assert((uintptr_t)allocation % 64 == 0);
  KGEN_CompilerRT_AlignedFree(allocation);

  CompilerRTArgumentList argument_list = {0};
  KGEN_CompilerRT_GetArgV(&argument_list);
  assert(argument_list.length == 1);
  assert(argument_list.arguments != NULL);
  assert(argument_list.arguments[0].length == 0);

  char first_argument[] = "embedded-host";
  char second_argument[] = "--test";
  char *arguments[] = {first_argument, second_argument};
  KGEN_CompilerRT_SetArgV(2, arguments);
  first_argument[0] = 'X';
  second_argument[0] = 'X';
  KGEN_CompilerRT_GetArgV(&argument_list);
  assert(argument_list.length == 2);
  assert(argument_list.arguments[0].length == strlen("embedded-host"));
  assert(memcmp(argument_list.arguments[0].data, "embedded-host",
                strlen("embedded-host")) == 0);
  assert(argument_list.arguments[1].length == strlen("--test"));
  assert(memcmp(argument_list.arguments[1].data, "--test", strlen("--test")) ==
         0);

  CompilerRTStringRef global_name = {.data = "test-global", .length = 11};
  void *named_value = KGEN_CompilerRT_GetOrCreateGlobal(
      global_name, create_test_value, destroy_test_value);
  assert(named_value != NULL);
  assert(KGEN_CompilerRT_GetOrCreateGlobal(global_name, create_test_value,
                                           destroy_test_value) == named_value);

  void *indexed_value = KGEN_CompilerRT_GetOrCreateGlobalIndexed(
      0, create_test_value, destroy_test_value);
  assert(indexed_value != NULL);
  assert(KGEN_CompilerRT_GetOrCreateGlobalIndexed(
             0, create_test_value, destroy_test_value) == indexed_value);

  KGEN_CompilerRT_DestroyGlobals();
  assert(destroyed_value_count == 2);
  KGEN_CompilerRT_DestroyGlobals();
  assert(destroyed_value_count == 2);

  puts("EMBEDDED_COMPILERRT_HOST_PASS cores=available argv=owned "
       "globals=recreatable aligned_alloc=passed");
  return 0;
}
