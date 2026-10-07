// Lets bionic's copy of FreeBSD msun build with glibc's headers, every
// function renamed msun_* so the shim (shim.c) can call both libraries.
// Forced in with -include by tools/linux/bionic_libm.sh.
#include <math.h>
#include <float.h>
#include <stdint.h>
#include <sys/types.h>
#include <endian.h>
#define __FBSDID(x)
#define __weak_reference(a, b)
#define __strong_reference(a, b)
#define __BEGIN_DECLS
#define __END_DECLS
#define _BYTE_ORDER __BYTE_ORDER
#define _LITTLE_ENDIAN __LITTLE_ENDIAN
#define _BIG_ENDIAN __BIG_ENDIAN
typedef uint32_t u_int32_t;
typedef uint64_t u_int64_t;
typedef double __double_t;
typedef float __float_t;
// math_private.h's long double helpers aren't needed and don't build here.
#undef LDBL_MANT_DIG
#define atan2 msun_atan2
#define atan2f msun_atan2f
#define atan msun_atan
#define atanf msun_atanf
#define sin msun_sin
#define cos msun_cos
#define __ieee754_rem_pio2 msun_rem_pio2
#define __kernel_rem_pio2 msun_kernel_rem_pio2
#define __kernel_sin msun_kernel_sin
#define __kernel_cos msun_kernel_cos
double msun_atan(double);
float msun_atanf(float);
