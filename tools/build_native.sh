#!/usr/bin/env bash
# Builds the slime_native GDExtension (the native simulation tick, chunk 5N)
# into addons/slime_native/bin/. See docs/dev/native.md.
#
#   tools/build_native.sh                  Linux x86_64, debug (tests, editor)
#   tools/build_native.sh --release        Linux x86_64, release
#   tools/build_native.sh --android        Android arm64-v8a, debug (the phone)
#   tools/build_native.sh --android --release
#   tools/build_native.sh --android --arch=x86_64
#                                          Android x86_64, debug (the emulator)
#   tools/build_native.sh --all            all five of the above, in that order
#   tools/build_native.sh --test           Linux debug, then the native tests
#                                          (tools/test.sh -gselect=test_native_)
#
# Builds are incremental (SCons): only what changed rebuilds. A lock
# (native/.build.lock, flock) serializes builds started in parallel (two test
# runs, two agents): the second waits for the first.
# Arguments after -- go to SCons (for example -- -j4, or -- verbose=yes).
# Environment: SCONS (default: scons on the PATH), ANDROID_HOME (default:
# ~/Android/Sdk), ANDROID_NDK_VERSION (default: 28.2.13676358, which must be
# installed under $ANDROID_HOME/ndk).
# Exit code: 0 when the libraries are built (and, with --test, the tests
# pass), non-zero otherwise.
set -euo pipefail

cd "$(dirname "$0")/.."

DEFAULT_NDK_VERSION=28.2.13676358

platform=linux
target=template_debug
arch=""
all=false
run_test=false
scons_args=()
while [ $# -gt 0 ]; do
	case "$1" in
	--android) platform=android ;;
	--linux) platform=linux ;;
	--debug) target=template_debug ;;
	--release) target=template_release ;;
	--arch=*) arch="${1#--arch=}" ;;
	--all) all=true ;;
	--test) run_test=true ;;
	--)
		shift
		scons_args+=("$@")
		break
		;;
	*)
		echo "tools/build_native.sh: unknown option $1 (see the header of this script)." >&2
		exit 2
		;;
	esac
	shift
done

if $run_test && { $all || [ "$platform" != linux ] || [ "$target" != template_debug ]; }; then
	echo "tools/build_native.sh: --test runs the Linux debug build only." >&2
	exit 2
fi

SCONS="${SCONS:-scons}"
if ! command -v "$SCONS" >/dev/null 2>&1; then
	echo "tools/build_native.sh: scons not found. Install it with 'uv tool install scons'" >&2
	echo "  (or 'pipx install scons'), see docs/dev/native.md." >&2
	exit 2
fi
if [ ! -f native/godot-cpp/SConstruct ]; then
	echo "tools/build_native.sh: native/godot-cpp is empty. Fetch it with" >&2
	echo "  git submodule update --init" >&2
	exit 2
fi

# The SCons arguments of one build: <platform> <target> <arch>.
build_one() {
	local b_platform="$1" b_target="$2" b_arch="$3"
	local args=(platform="$b_platform" target="$b_target" arch="$b_arch")
	if [ "$b_platform" = android ]; then
		local android_home="${ANDROID_HOME:-$HOME/Android/Sdk}"
		local ndk_version="${ANDROID_NDK_VERSION:-$DEFAULT_NDK_VERSION}"
		if [ ! -d "$android_home/ndk/$ndk_version" ]; then
			echo "tools/build_native.sh: no Android NDK $ndk_version under $android_home/ndk." >&2
			echo "  Install it, or set ANDROID_HOME / ANDROID_NDK_VERSION, see docs/dev/native.md." >&2
			return 2
		fi
		args+=(ANDROID_HOME="$android_home" ndk_version="$ndk_version")
	fi
	echo "tools/build_native.sh: $b_platform $b_target $b_arch"
	"$SCONS" -C native/slime_native "${args[@]}" "${scons_args[@]}"
	# SCons goes by content and leaves an up-to-date library alone; dated
	# now, it reads as newer than its sources (tools/test.sh's check).
	touch "addons/slime_native/bin/libslime_native.$b_platform.$b_target.$b_arch.so"
}

# One build at a time, whoever started it: wait for the lock.
exec 9>native/.build.lock
flock 9

if $all; then
	build_one linux template_debug x86_64
	build_one linux template_release x86_64
	build_one android template_debug arm64
	build_one android template_release arm64
	build_one android template_debug x86_64
else
	if [ -z "$arch" ]; then
		if [ "$platform" = android ]; then arch=arm64; else arch=x86_64; fi
	fi
	build_one "$platform" "$target" "$arch"
fi

# Release the lock before the tests: tools/test.sh may call this script.
exec 9>&-

if $run_test; then
	exec tools/test.sh -gselect=test_native_
fi
