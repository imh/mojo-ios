#include <assert.h>
#include <stdint.h>
#include <stdio.h>

extern int32_t mojo_ios_metal_vector_add(const float *left, const float *right,
                                         float *output, int64_t count);
extern int32_t mojo_ios_metal_feature_matrix(float *output);
extern int32_t mojo_ios_metal_reject_cuda_launch_attribute(void);

int main(void) {
  const float left[] = {1.0f, -2.0f, 3.5f, 4.0f, 9.0f, 0.25f, -8.0f, 2.0f};
  const float right[] = {2.0f, 5.0f, -1.5f, 0.5f, 1.0f, 0.75f, 3.0f, -4.0f};
  const float expected[] = {3.0f, 3.0f, 2.0f, 4.5f, 10.0f, 1.0f, -5.0f,
                            -2.0f};
  float output[8] = {0};

  int32_t status = mojo_ios_metal_vector_add(left, right, output, 8);
  assert(status == 0);
  for (size_t element_index = 0; element_index < 8; ++element_index) {
    if (output[element_index] != expected[element_index])
      fprintf(stderr, "element %zu: expected %g, got %g\n", element_index,
              expected[element_index], output[element_index]);
    assert(output[element_index] == expected[element_index]);
  }

  float feature_matrix_output[64] = {0};
  status = mojo_ios_metal_feature_matrix(feature_matrix_output);
  assert(status == 0);
  for (size_t element_index = 0; element_index < 64; ++element_index) {
    float expected_value = (float)(2 * element_index + 15);
    if (feature_matrix_output[element_index] != expected_value)
      fprintf(stderr, "feature element %zu: expected %g, got %g\n",
              element_index, expected_value,
              feature_matrix_output[element_index]);
    assert(feature_matrix_output[element_index] == expected_value);
  }

  status = mojo_ios_metal_reject_cuda_launch_attribute();
  assert(status == 0);

  puts("verified Mojo heterogeneous arguments, scalar/SIMD/struct captures, "
       "nested and repeated device pointers, 3D dispatch, multi-kernel "
       "composition, threadgroup memory, and explicit launch-attribute "
       "rejection through the standard Metal DeviceContext");
  return 0;
}
