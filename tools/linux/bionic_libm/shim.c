// LD_PRELOAD shim: atan2, atan2f, sin and cos from Android bionic's libm
// (FreeBSD msun, built by tools/linux/bionic_libm.sh) instead of glibc's, so a
// desktop run gives the phone's results for them. Each call also runs
// glibc's (dlsym RTLD_NEXT) and counts the calls whose results differ; at
// exit it prints "SHIM <name>=<differing>/<calls>[*] ...", * on the replaced
// ones. SHIM_FUNCS (comma-separated names) picks which are replaced; unset,
// all four are.
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

double msun_atan2(double, double);
float msun_atan2f(float, float);
double msun_sin(double);
double msun_cos(double);

typedef double (*fn_dd)(double, double);
typedef float (*fn_ff)(float, float);
typedef double (*fn_d)(double);

enum { ATAN2, ATAN2F, SIN, COS, COUNT };
static const char *names[COUNT] = {"atan2", "atan2f", "sin", "cos"};
static unsigned long calls[COUNT], diffs[COUNT];
static int replaced[COUNT] = {-1, -1, -1, -1};

static int is_replaced(int i) {
	if (replaced[i] < 0) {
		const char *list = getenv("SHIM_FUNCS");
		char padded[256], name[16];
		if (list == NULL) {
			replaced[i] = 1;
		} else {
			snprintf(padded, sizeof padded, ",%s,", list);
			snprintf(name, sizeof name, ",%s,", names[i]);
			replaced[i] = strstr(padded, name) != NULL;
		}
	}
	return replaced[i];
}

#define PICK(i, ours, theirs) \
	calls[i]++; \
	if (ours != theirs) \
		diffs[i]++; \
	return is_replaced(i) ? ours : theirs

double atan2(double y, double x) {
	static fn_dd glibc = NULL;
	if (glibc == NULL)
		glibc = (fn_dd)dlsym(RTLD_NEXT, "atan2");
	double ours = msun_atan2(y, x), theirs = glibc(y, x);
	PICK(ATAN2, ours, theirs);
}

float atan2f(float y, float x) {
	static fn_ff glibc = NULL;
	if (glibc == NULL)
		glibc = (fn_ff)dlsym(RTLD_NEXT, "atan2f");
	float ours = msun_atan2f(y, x), theirs = glibc(y, x);
	PICK(ATAN2F, ours, theirs);
}

double sin(double x) {
	static fn_d glibc = NULL;
	if (glibc == NULL)
		glibc = (fn_d)dlsym(RTLD_NEXT, "sin");
	double ours = msun_sin(x), theirs = glibc(x);
	PICK(SIN, ours, theirs);
}

double cos(double x) {
	static fn_d glibc = NULL;
	if (glibc == NULL)
		glibc = (fn_d)dlsym(RTLD_NEXT, "cos");
	double ours = msun_cos(x), theirs = glibc(x);
	PICK(COS, ours, theirs);
}

__attribute__((destructor)) static void report(void) {
	fprintf(stderr, "SHIM");
	for (int i = 0; i < COUNT; i++)
		fprintf(stderr, " %s=%lu/%lu%s", names[i], diffs[i], calls[i], is_replaced(i) ? "*" : "");
	fprintf(stderr, "\n");
}
