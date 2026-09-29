extends GutTest
## The parent-facing strings (src/parent/parent_text.gd): one table, every
## key in English and in French (the French says "vous" to the parent), and
## the time-left format.

# @test-link [[req_parent_gate_and_access]]


func test_every_key_has_both_languages() -> void:
	assert_gt(ParentText.TABLE.size(), 0)
	for key in ParentText.TABLE:
		for lang in ParentText.LANGUAGES:
			assert_ne(ParentText.text(key, lang), "", "%s in %s" % [key, lang])
		assert_eq(ParentText.TABLE[key].size(), ParentText.LANGUAGES.size(), "%s: no extra language" % key)


func test_the_starter_keys() -> void:
	assert_eq(ParentText.text("wake_early", "en"), "Wake early")
	assert_eq(ParentText.text("wake_early", "fr"), "Réveiller")
	assert_eq(ParentText.text("enter_code", "fr"), "Saisissez le code parent")
	assert_eq(ParentText.text("wait", "en").format({"s": 30}), "Too many tries. Wait 30 s.")
	assert_eq(ParentText.text("time_left_session", "fr").format({"t": "12:34"}), "Temps restant : 12:34")
	for key in ["leave", "settings", "forgot_code", "forgot_code_stub", "time_left_bedtime", "no_session"]:
		assert_true(ParentText.TABLE.has(key), key)


func test_the_settings_keys() -> void:
	assert_eq(ParentText.text("close", "fr"), "Fermer")
	assert_eq(ParentText.text("closing_soon", "en").format({"s": 10}), "Settings close in 10 s")
	assert_eq(ParentText.text("closing_soon", "fr").format({"s": 10}), "Les réglages se ferment dans 10 s")
	assert_eq(ParentText.text("level_name", "fr").format({"id": "test"}), "Niveau test")
	for key in ["change_code", "new_code", "new_code_again", "codes_differ", "code_changed", "back",
			"delete_save", "delete_confirm", "delete_yes", "delete_no", "save_deleted", "delete_failed"]:
		assert_true(ParentText.TABLE.has(key), key)
	assert_true("{level}" in ParentText.text("delete_confirm", "en"), "the confirmation names the level")
	assert_true("{level}" in ParentText.text("delete_confirm", "fr"))


func test_the_setup_keys() -> void:
	assert_eq(ParentText.text("setup_step", "en").format({"n": 2, "total": 4}), "Step 2 of 4")
	assert_eq(ParentText.text("setup_step", "fr").format({"n": 2, "total": 4}), "Étape 2 sur 4")
	assert_eq(ParentText.text("next", "fr"), "Suivant")
	for key in ["setup_done", "setup_welcome_title", "setup_welcome", "setup_code_title", "setup_code",
			"setup_code_again", "setup_forgotten_title", "setup_forgotten", "setup_pinning_title", "setup_pinning"]:
		assert_true(ParentText.TABLE.has(key), key)
	assert_true("vous" in ParentText.text("setup_welcome", "fr").to_lower(), "French says vous")
	assert_true("Ask for PIN before unpinning" in ParentText.text("setup_pinning", "en"))
	assert_true("erases all progress" in ParentText.text("setup_forgotten", "en"))


func test_the_language_override() -> void:
	ParentText.language_override = "fr"
	assert_eq(ParentText.language(), "fr")
	ParentText.language_override = "en"
	assert_eq(ParentText.language(), "en")
	ParentText.language_override = ""
	assert_eq(ParentText.language() == "fr", OS.get_locale_language() == "fr", "unset: the phone's")


func test_the_language_is_english_or_french() -> void:
	var lang := ParentText.language()
	assert_true(lang in ParentText.LANGUAGES)
	assert_eq(lang == "fr", OS.get_locale_language() == "fr")


func test_time_left_is_minutes_and_seconds() -> void:
	assert_eq(ParentText.time_left(754000), "12:34")
	assert_eq(ParentText.time_left(0), "0:00")
	assert_eq(ParentText.time_left(59001), "1:00", "whole seconds, rounded up: 0:00 only at the end")
	assert_eq(ParentText.time_left(1), "0:01")
	assert_eq(ParentText.time_left(60000), "1:00")
	assert_eq(ParentText.time_left(5_400_000), "90:00", "minutes don't roll into hours")
	assert_eq(ParentText.time_left(-5000), "0:00", "a negative is clamped")


func test_an_unknown_key_or_language_fails_loudly() -> void:
	assert_eq(ParentText.text("no_such_key", "en"), "")
	assert_push_error("unknown key")
	assert_eq(ParentText.text("leave", "de"), "")
	assert_push_error("unknown language")
