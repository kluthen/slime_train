#!/usr/bin/env bash
# Exports Slime Train as an Android APK from the command line (Gradle build,
# with the SlimePlatform plugin). Builds the plugin first
# (tools/android/build_plugin.sh), and installs Godot's Android build template
# into android/build/ (not tracked) when it is missing.
#
#   tools/android/export.sh debug     preset "Android debug":
#                                     build/slime-train-debug.apk
#                                     (arm64-v8a phone + x86_64 emulator)
#   tools/android/export.sh release   preset "Android release":
#                                     build/slime-train-release.apk (arm64-v8a)
#
# Signing: debug uses the debug keystore of the Godot editor settings.
# Release needs these environment variables (never commit a keystore or a
# password; the store and key passwords must be the same):
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH, GODOT_ANDROID_KEYSTORE_RELEASE_USER,
#   GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
# Environment: GODOT (default: godot on the PATH, version 4.7.2). The Gradle
# build uses the JDK and SDK of the editor settings (export/android/*: JDK 21,
# ~/Android/Sdk with build-tools 36.1.0 and NDK 29.0.14206865); JAVA_HOME_21
# (default: /usr/lib/jvm/java-21-openjdk-amd64) only stops Gradle afterwards.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GODOT="${GODOT:-godot}"

case "${1:-}" in
debug)
	preset="Android debug"
	apk="$root/build/slime-train-debug.apk"
	export_flag=--export-debug
	;;
release)
	preset="Android release"
	apk="$root/build/slime-train-release.apk"
	export_flag=--export-release
	for var in GODOT_ANDROID_KEYSTORE_RELEASE_PATH GODOT_ANDROID_KEYSTORE_RELEASE_USER \
		GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD; do
		if [ -z "${!var:-}" ]; then
			echo "tools/android/export.sh: release signing needs $var (see this script's header)." >&2
			exit 2
		fi
	done
	;;
*)
	echo "usage: tools/android/export.sh debug|release" >&2
	exit 2
	;;
esac

"$root/tools/android/build_plugin.sh"

godot_args=(--headless --path "$root")
if [ ! -d "$root/android/build" ]; then
	# Only honoured together with an --export-* flag.
	godot_args+=(--install-android-build-template)
fi

# Godot's Gradle build leaves a daemon running: stop it on the way out
# (set KEEP_GRADLE_DAEMON=1 to keep it for faster repeated exports).
stop_template_daemon() {
	if [ "${KEEP_GRADLE_DAEMON:-0}" != 1 ] && [ -x "$root/android/build/gradlew" ]; then
		(cd "$root/android/build" &&
			JAVA_HOME="${JAVA_HOME_21:-/usr/lib/jvm/java-21-openjdk-amd64}" \
				./gradlew --stop --quiet >/dev/null 2>&1) || true
	fi
}
trap stop_template_daemon EXIT

mkdir -p "$root/build"
rm -f "$apk"
"$GODOT" "${godot_args[@]}" "$export_flag" "$preset" "$apk"

if [ ! -f "$apk" ]; then
	echo "tools/android/export.sh: the export did not produce $apk." >&2
	exit 1
fi
echo "$apk"
