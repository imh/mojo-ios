#include <assert.h>
#include <stddef.h>

typedef void (*CoreAICompletionFunction)(void *request,
                                         const char *error_message);

// Metal-only linkage tests intentionally omit the generated Swift Core AI
// bridge.  Supply a test-local implementation that fails explicitly if a
// regression accidentally submits Core AI work.
void MojoIOSCoreAI_executeMatmulMatmulF32_2x3x4x2(
    const float *input, const float *first_weights,
    const float *second_weights, float *output, void *request,
    CoreAICompletionFunction completion) {
  (void)input;
  (void)first_weights;
  (void)second_weights;
  (void)output;
  assert(completion != NULL);
  completion(request,
             "Core AI is unavailable in the Metal-only linkage test");
}
