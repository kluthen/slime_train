# Everyday build commands. Needs Godot 4.7.2 on the PATH as `godot`, with the
# Android SDK, Java and debug keystore set in the editor settings
# (Editor > Editor Settings > Export > Android), and `adb` for `make install`.
#   make apk      export the debug APK to build/slime-train-debug.apk
#   make install  install that APK on the connected phone (exports it first if missing)
#   make run      run the game on the desktop
# Override the tools with GODOT=... or ADB=...; pick a phone with ANDROID_SERIAL=...

GODOT ?= godot
ADB ?= adb
PRESET := Android debug
APK := build/slime-train-debug.apk

.PHONY: apk install run

apk:
	@mkdir -p build
	$(GODOT) --headless --import
	$(GODOT) --headless --export-debug "$(PRESET)" $(APK)
	@test -f $(APK) || { echo "make apk: the export produced no APK." >&2; exit 1; }

$(APK):
	$(MAKE) apk

install: $(APK)
	@$(ADB) devices | grep -qw 'device$$' || { echo "make install: no phone connected (check USB debugging and 'adb devices')." >&2; exit 1; }
	$(ADB) install -r $(APK)

run:
	$(GODOT) --path .
