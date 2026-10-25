/*
 * Force-included when building the legacy macOS binaries (AG_LEGACY_LIBCXX_ROOT).
 *
 * The SDK's <simd/math.h> wraps __sincospi() and __sincospif() in inline helpers, but <math.h> only declares them
 * for deployment targets from macOS 10.9. Nothing calls the helpers, so declaring the functions is enough.
 */
#pragma once

#ifdef __cplusplus
extern "C" {
void __sincospi(double, double*, double*);
void __sincospif(float, float*, float*);
}
#endif
