package com.slimetrain.platform;

import android.app.Activity;
import android.app.ActivityManager;
import android.app.KeyguardManager;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.graphics.Rect;
import android.hardware.biometrics.BiometricManager;
import android.hardware.biometrics.BiometricPrompt;
import android.os.Build;
import android.os.CancellationSignal;
import android.util.DisplayMetrics;
import android.util.Log;
import android.view.View;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Set;

/**
 * SlimePlatform: the phone services Slime Train needs from Android, exposed
 * to GDScript as the engine singleton "SlimePlatform" (wrapped by
 * src/platform/phone_platform.gd).
 *
 * <p>Threading: Godot calls the {@code @UsedByGodot} methods on its render
 * thread. Every piece of mutable state below is only read or written on the
 * host (UI) thread, via {@link #runOnHostThread} or the lifecycle callbacks,
 * so it needs no locking. The signal is emitted back on the render thread.
 */
public class SlimePlatformPlugin extends GodotPlugin {
	private static final String TAG = "SlimePlatform";
	private static final String PLUGIN_NAME = "SlimePlatform";
	private static final SignalInfo CREDENTIAL_FINISHED =
			new SignalInfo("credential_finished", Boolean.class);
	/** Request code of the API 24-29 confirm-credential activity (fits 16 bits). */
	private static final int CONFIRM_CREDENTIAL_REQUEST = 5207;
	private static final int[] NO_RECTS = new int[0];
	/**
	 * The launch intent's string-array extra holding extra user arguments for
	 * a debuggable build ({@link #getCommandLineParams}), for example
	 * {@code am start ... --esa slime_args --test-mode,--perf-log=5}.
	 */
	static final String LAUNCH_ARGS_EXTRA = "slime_args";
	/** Godot's separator: every argument after the first one is a user argument. */
	private static final String USER_ARGS_SEPARATOR = "--";

	/** True between onMainResume and onMainPause (UI thread only). */
	private boolean resumed = false;
	/** startPinning arrived while not resumed: pin on the next resume (UI thread only). */
	private boolean pinningPending = false;
	/** A credential prompt is showing and has not reported yet (UI thread only). */
	private boolean credentialPending = false;
	/** Flattened [x, y, w, h, ...] back-gesture exclusion rects (UI thread only). */
	private int[] exclusionRects = NO_RECTS;
	/** Re-applies the exclusion rects after each layout; attached once (UI thread only). */
	private View.OnLayoutChangeListener layoutListener = null;

	/**
	 * Creates the plugin; Godot instantiates it from the AAR manifest meta-data.
	 *
	 * @param godot the Godot instance hosting the plugin
	 */
	public SlimePlatformPlugin(Godot godot) {
		super(godot);
	}

	/**
	 * Returns the singleton name GDScript sees ("SlimePlatform"); it must match
	 * the manifest meta-data suffix.
	 */
	@Override
	public String getPluginName() {
		return PLUGIN_NAME;
	}

	/**
	 * Hands Godot extra user arguments from the launch intent, in a
	 * debuggable build only (the debug export; ApplicationInfo.FLAG_DEBUGGABLE):
	 * a release build returns none, whatever the intent holds. Godot 4.7
	 * strips its own {@code command_line_params} extra from an intent to the
	 * exported launcher, and adb can't start the non-exported GodotApp, so a
	 * measurement run (tools/android/perf.sh) passes its arguments in the
	 * {@link #LAUNCH_ARGS_EXTRA} string-array extra instead. Godot calls this
	 * once, while it initialises the engine, and appends the result to its
	 * command line; a "--" goes first unless the command line already has
	 * one, so they arrive as user arguments (OS.get_cmdline_user_args()).
	 *
	 * @param current the command line so far
	 * @return the arguments to append (empty when there are none to add)
	 */
	@Override
	public List<String> getCommandLineParams(List<String> current) {
		Activity activity = getActivity();
		if (activity == null) {
			Log.w(TAG, "getCommandLineParams: no host activity yet, no launch arguments read");
			return Collections.emptyList();
		}
		if (!isDebuggable(activity)) {
			return Collections.emptyList();
		}
		Intent intent = activity.getIntent();
		String[] extra = intent == null ? null : intent.getStringArrayExtra(LAUNCH_ARGS_EXTRA);
		if (extra == null || extra.length == 0) {
			return Collections.emptyList();
		}
		List<String> params = new ArrayList<>(extra.length + 1);
		if (!current.contains(USER_ARGS_SEPARATOR)) {
			params.add(USER_ARGS_SEPARATOR);
		}
		Collections.addAll(params, extra);
		Log.i(TAG, "launch arguments from the intent: " + params);
		return params;
	}

	/** Whether this is a debuggable build (the debug export, never the release one). */
	private static boolean isDebuggable(Activity activity) {
		return (activity.getApplicationInfo().flags & ApplicationInfo.FLAG_DEBUGGABLE) != 0;
	}

	/** Declares the plugin's only signal, {@code credential_finished(ok: bool)}. */
	@Override
	public Set<SignalInfo> getPluginSignals() {
		return Collections.singleton(CREDENTIAL_FINISHED);
	}

	/** Tracks the resumed state and performs a pinning request deferred until now. */
	@Override
	public void onMainResume() {
		resumed = true;
		if (pinningPending) {
			pinningPending = false;
			startLockTaskNow();
		}
	}

	/** Tracks the resumed state: startLockTask is only allowed while resumed. */
	@Override
	public void onMainPause() {
		resumed = false;
	}

	/**
	 * Receives the result of the API 24-29 confirm-credential activity and
	 * reports it through {@code credential_finished}.
	 */
	@Override
	public void onMainActivityResult(int requestCode, int resultCode, Intent data) {
		if (requestCode == CONFIRM_CREDENTIAL_REQUEST) {
			finishCredential(resultCode == Activity.RESULT_OK);
		}
	}

	// @spec-link [[req_screen_pinning]]
	/**
	 * Asks Android to pin the screen (startLockTask). Without a device-owner
	 * allowlist this is screen pinning: Android shows its own confirmation the
	 * first time. If the activity is not resumed yet, the request waits for
	 * the next resume, once.
	 */
	@UsedByGodot
	public void startPinning() {
		runOnHostThread(() -> {
			if (resumed) {
				startLockTaskNow();
			} else {
				pinningPending = true;
			}
		});
	}

	// @spec-link [[req_screen_pinning]]
	/** Unpins the screen (stopLockTask); a no-op when the screen is not pinned. */
	@UsedByGodot
	public void stopPinning() {
		runOnHostThread(() -> {
			pinningPending = false;
			if (isPinned()) {
				requireActivity().stopLockTask();
			}
		});
	}

	// @spec-link [[req_screen_pinning]]
	/** Returns true while the app is in lock task mode (pinned or locked). */
	@UsedByGodot
	public boolean isPinned() {
		ActivityManager manager = requireActivity().getSystemService(ActivityManager.class);
		return manager.getLockTaskModeState() != ActivityManager.LOCK_TASK_MODE_NONE;
	}

	// @spec-link [[req_parent_gate_and_access]]
	/** Returns true when the device has a screen lock (PIN, pattern or password). */
	@UsedByGodot
	public boolean isDeviceSecure() {
		KeyguardManager keyguard = requireActivity().getSystemService(KeyguardManager.class);
		return keyguard.isDeviceSecure();
	}

	// @spec-link [[req_parent_gate_and_access]]
	/**
	 * Asks for the device's screen lock (or a biometric) and emits
	 * {@code credential_finished(ok)} exactly once: true on success, false on
	 * cancel, error or when the device has no screen lock. A call made while a
	 * prompt is already showing is ignored (it emits nothing).
	 *
	 * @param title    the prompt's title; must not be empty
	 * @param subtitle the prompt's subtitle; may be empty
	 */
	@UsedByGodot
	public void confirmCredential(String title, String subtitle) {
		if (title == null || title.isEmpty()) {
			throw new IllegalArgumentException("confirmCredential: title must not be empty");
		}
		runOnHostThread(() -> {
			if (credentialPending) {
				return;
			}
			credentialPending = true;
			if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
				showBiometricPrompt(title, subtitle);
			} else {
				showConfirmCredentialActivity(title, subtitle);
			}
		});
	}

	// @spec-link [[req_screen_pinning]]
	/**
	 * Keeps the system back gesture out of the given rects (API 29+; a no-op
	 * below) and re-applies them after every layout. The rects are flattened
	 * [x, y, w, h, ...] in window pixels, which equal decor-view coordinates
	 * in the edge-to-edge window. An empty array clears them.
	 *
	 * @param rects flattened rects; length must be a multiple of 4
	 */
	@UsedByGodot
	public void setGestureExclusion(int[] rects) {
		if (rects == null || rects.length % 4 != 0) {
			throw new IllegalArgumentException("setGestureExclusion: expects [x, y, w, h, ...]");
		}
		final int[] copy = rects.clone();
		runOnHostThread(() -> {
			exclusionRects = copy;
			attachLayoutListenerOnce();
			applyGestureExclusion();
		});
	}

	// @spec-link [[req_parent_gate_and_access]]
	/**
	 * Returns the screen's physical density, pixels per inch: the mean of the
	 * display metrics' xdpi and ydpi. Unlike densityDpi (what Godot's
	 * screen_get_dpi() reports), a logical bucket that the user's "display
	 * size" setting changes, these are the panel's own pixels per inch, so the
	 * game can size its targets in real millimetres. Some devices report
	 * bogus values here: the caller checks them against densityDpi. On API
	 * 30+ they come from the activity's resources (the display the activity is
	 * on), below from the default display's real metrics.
	 */
	@UsedByGodot
	public float getPhysicalDpi() {
		Activity activity = requireActivity();
		DisplayMetrics metrics;
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
			metrics = activity.getResources().getDisplayMetrics();
		} else {
			metrics = realMetricsBeforeR(activity);
		}
		return (metrics.xdpi + metrics.ydpi) / 2f;
	}

	// @spec-link [[req_screen_pinning]]
	/**
	 * Sends the app to the background (moveTaskToBack), as the Home button
	 * would. Android refuses it while the screen is pinned: unpin first.
	 */
	@UsedByGodot
	public void moveToBackground() {
		runOnHostThread(() -> requireActivity().moveTaskToBack(true));
	}

	/**
	 * Calls startLockTask on the UI thread while resumed. Android throws when
	 * the task is not in front (a race with the user leaving); that is logged,
	 * not fatal, and the game reads the state back with isPinned().
	 */
	private void startLockTaskNow() {
		try {
			requireActivity().startLockTask();
		} catch (IllegalArgumentException | IllegalStateException | SecurityException e) {
			Log.w(TAG, "startLockTask refused", e);
		}
	}

	/** Shows the framework BiometricPrompt allowing a biometric or the screen lock (API 30+). */
	private void showBiometricPrompt(String title, String subtitle) {
		Activity activity = requireActivity();
		BiometricPrompt.Builder builder = new BiometricPrompt.Builder(activity)
				.setTitle(title)
				.setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_WEAK
						| BiometricManager.Authenticators.DEVICE_CREDENTIAL);
		if (subtitle != null && !subtitle.isEmpty()) {
			builder.setSubtitle(subtitle);
		}
		// No negative button: Android throws when one is set with DEVICE_CREDENTIAL.
		builder.build().authenticate(new CancellationSignal(), activity.getMainExecutor(),
				new BiometricPrompt.AuthenticationCallback() {
					@Override
					public void onAuthenticationSucceeded(BiometricPrompt.AuthenticationResult result) {
						finishCredential(true);
					}

					@Override
					public void onAuthenticationError(int errorCode, CharSequence errString) {
						finishCredential(false);
					}
				});
	}

	/**
	 * Starts the keyguard's confirm-credential activity (API 24-29); false at
	 * once without a screen lock. Its intent is deprecated from API 29, but
	 * it only runs below API 30, where BiometricPrompt lacks DEVICE_CREDENTIAL.
	 */
	@SuppressWarnings("deprecation")
	private void showConfirmCredentialActivity(String title, String subtitle) {
		Activity activity = requireActivity();
		KeyguardManager keyguard = activity.getSystemService(KeyguardManager.class);
		Intent intent = keyguard.createConfirmDeviceCredentialIntent(title, subtitle);
		if (intent == null) {
			finishCredential(false);
			return;
		}
		activity.startActivityForResult(intent, CONFIRM_CREDENTIAL_REQUEST);
	}

	/** Ends the pending credential prompt and emits its result on the render thread. */
	private void finishCredential(boolean ok) {
		if (!credentialPending) {
			return;
		}
		credentialPending = false;
		final Boolean result = ok;
		runOnRenderThread(() -> emitSignal(CREDENTIAL_FINISHED, result));
	}

	/** Attaches the decor-view layout listener that re-applies the exclusion rects. */
	private void attachLayoutListenerOnce() {
		if (layoutListener != null) {
			return;
		}
		layoutListener = (view, left, top, right, bottom, oldLeft, oldTop, oldRight, oldBottom) ->
				applyGestureExclusion();
		decorView().addOnLayoutChangeListener(layoutListener);
	}

	/** Hands the stored rects to the decor view (API 29+). */
	private void applyGestureExclusion() {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
			return;
		}
		List<Rect> list = new ArrayList<>(exclusionRects.length / 4);
		for (int i = 0; i < exclusionRects.length; i += 4) {
			int x = exclusionRects[i];
			int y = exclusionRects[i + 1];
			list.add(new Rect(x, y, x + exclusionRects[i + 2], y + exclusionRects[i + 3]));
		}
		decorView().setSystemGestureExclusionRects(list);
	}

	/**
	 * Returns the default display's real metrics (the whole panel), the API
	 * 24-29 way (deprecated from API 30, where getPhysicalDpi reads the
	 * activity's resources instead).
	 */
	@SuppressWarnings("deprecation")
	private static DisplayMetrics realMetricsBeforeR(Activity activity) {
		DisplayMetrics metrics = new DisplayMetrics();
		activity.getWindowManager().getDefaultDisplay().getRealMetrics(metrics);
		return metrics;
	}

	/** Returns the window's decor view, whose coordinates are the window's pixels. */
	private View decorView() {
		return requireActivity().getWindow().getDecorView();
	}

	/** Returns the host activity; fails loudly if the plugin is not attached to one. */
	private Activity requireActivity() {
		Activity activity = getActivity();
		if (activity == null) {
			throw new IllegalStateException("SlimePlatform: no host activity");
		}
		return activity;
	}
}
