#!/usr/bin/env bash
# Builds the slime_native GDExtension (the native simulation tick, D96) into
# native/bin/. See docs/dev/native.md.
#
#   tools/build_native.sh                  Linux x86_64, debug (tests, editor)
#   tools/build_native.sh --release        Linux x86_64, release
#   tools/build_native.sh --android        Android arm64-v8a, debug (the phone)
#   tools/build_native.sh --android --release
#   tools/build_native.sh --test           Linux debug, then its GUT test
#                                          (tests/native/, not in tools/test.sh)
#
# Arguments after -- go to SCons (for example -- -j4, or -- verbose=yes).
# Environment: SCONS (default: scons on the PATH), ANDROID_HOME (default:
# ~/Android/Sdk), ANDROID_NDK_VERSION (default: the newest NDK installed
# under $ANDROID_HOME/ndk).
# Exit code: 0 when the library is built (and, with --test, the test passes),
# non-zero otherwise.
set -euo pipefail

cd "$(dirname "$0")/.."

platform=linux
target=template_debug
run_test=false
scons_args=()
while [ $# -gt 0 ]; do
	case "$1" in
	--android) platform=android ;;
	--linux) platform=linux ;;
	--debug) target=template_debug ;;
	--release) target=template_release ;;
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

if $run_test && { [ "$platform" != linux ] || [ "$target" != template_debug ]; }; then
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

args=(platform="$platform" target="$target")
if [ "$platform" = android ]; then
	android_home="${ANDROID_HOME:-$HOME/Android/Sdk}"
	ndk_version="${ANDROID_NDK_VERSION:-}"
	if [ -z "$ndk_version" ] && [ -d "$android_home/ndk" ]; then
		ndk_version="$(ls "$android_home/ndk" | sort -V | tail -n 1)"
	fi
	if [ -z "$ndk_version" ] || [ ! -d "$android_home/ndk/$ndk_version" ]; then
		echo "tools/build_native.sh: no Android NDK under $android_home/ndk." >&2
		echo "  Set ANDROID_HOME (and ANDROID_NDK_VERSION), see docs/dev/native.md." >&2
		exit 2
	fi
	args+=(arch=arm64 ANDROID_HOME="$android_home" ndk_version="$ndk_version")
else
	args+=(arch=x86_64)
fi

"$SCONS" -C native/slime_native "${args[@]}" "${scons_args[@]}"

if $run_test; then
	# tools/test.sh keeps chunk 0's guarantees (import first, run marker);
	# -gdir replaces the directories of .gutconfig.json.
	exec tools/test.sh -gdir=res://tests/native/
fi
