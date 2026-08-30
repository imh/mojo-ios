#include <metal_stdlib>

using namespace metal;

kernel void metal_toolchain_smoke(
    device const float *left [[buffer(0)]],
    device const float *right [[buffer(1)]],
    device float *output [[buffer(2)]],
    constant long &count [[buffer(3)]],
    uint element_index [[thread_position_in_grid]]) {
  if (element_index < count)
    output[element_index] = left[element_index] + right[element_index];
}
