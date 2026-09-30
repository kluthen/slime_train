#!/usr/bin/env bash
# Builds the SlimePlatform Android plugin (native/android_plugin/, Java) and
# copies its AARs where the export plugin looks for them:
#   addons/slime_platform/bin/debug/SlimePlatform-debug.aar
#   addons/slime_platform/bin/release/SlimePlatform-release.aar
#
#   tools/android/build_plugin.sh
#
# Gradle 8.14 cannot run on the newest JDKs (25), so the build always runs on
# JDK 21, whatever JAVA_HOME says.
# Environment: JAVA_HOME_21 (default: /usr/lib/jvm/java-21-openjdk-amd64),
# ANDROID_HOME (default: ~/Android/Sdk; needs platforms;android-36).
# The Gradle daemon is stopped at the end (set KEEP_GRADLE_DAEMON=1 to keep it).
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
project="$root/native/android_plugin"
out="$root/addons/slime_platform/bin"

export JAVA_HOME="${JAVA_HOME_21:-/usr/lib/jvm/java-21-openjdk-amd64}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
if [ ! -x "$JAVA_HOME/bin/java" ]; then
	echo "tools/android/build_plugin.sh: no JDK 21 at $JAVA_HOME (set JAVA_HOME_21)." >&2
	exit 2
fi
if [ ! -d "$ANDROID_HOME/platforms" ]; then
	echo "tools/android/build_plugin.sh: no Android SDK at $ANDROID_HOME (set ANDROID_HOME)." >&2
	exit 2
fi

cd "$project"
stop_daemon() {
	if [ "${KEEP_GRADLE_DAEMON:-0}" != 1 ]; then
		./gradlew --stop --quiet >/dev/null 2>&1 || true
	fi
}
trap stop_daemon EXIT

./gradlew --quiet :plugin:assembleDebug :plugin:assembleRelease

for build in debug release; do
	aar="plugin/build/outputs/aar/SlimePlatform-$build.aar"
	if [ ! -f "$aar" ]; then
		echo "tools/android/build_plugin.sh: Gradle did not produce $aar." >&2
		exit 1
	fi
	mkdir -p "$out/$build"
	cp "$aar" "$out/$build/"
	echo "$out/$build/SlimePlatform-$build.aar"
done
