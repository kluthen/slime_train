class_name ParentText
extends RefCounted
## Every parent-facing string, in English and French (the French says "vous"
## to the parent). The child sees no text. A plain table rather than Godot's
## .po/.csv translations: no import step, and it can be tested headless.
##
## Adding a string: add its key to TABLE with a value in EVERY language of
## LANGUAGES (test_parent_text checks it). Placeholders are {name}, filled by
## the caller with String.format().
# @spec-link [[req_parent_gate_and_access]]

## The languages, the first being the one used unless the phone is in French.
const LANGUAGES := ["en", "fr"]

## Key -> {language -> text}.
const TABLE := {
	"wake_early": {"en": "Wake early", "fr": "Réveiller"},
	"leave": {"en": "Leave", "fr": "Quitter"},
	"settings": {"en": "Settings", "fr": "Réglages"},
	"enter_code": {"en": "Enter the parent code", "fr": "Saisissez le code parent"},
	"delete": {"en": "Delete", "fr": "Effacer"},
	"forgot_code": {"en": "Forgot the code?", "fr": "Code oublié ?"},
	"forgot_no_lock": {"en": "This phone has no screen lock, so you can't set a new code here. The only way out is "
			+ "to clear the app's data in Android settings, and that erases all progress.",
			"fr": "Ce téléphone n'a pas de verrouillage de l'écran : vous ne pouvez donc pas choisir un nouveau "
			+ "code ici. La seule solution est d'effacer les données de l'application dans les paramètres "
			+ "d'Android, ce qui efface toute la progression."},
	"forgot_confirm_title": {"en": "Confirm it's you", "fr": "Confirmez votre identité"},
	"forgot_confirm_subtitle": {"en": "Use your phone's screen lock to set a new parent code",
			"fr": "Utilisez le verrouillage de l'écran de votre téléphone pour choisir un nouveau code parent"},
	"forgot_new_code_title": {"en": "Set a new parent code", "fr": "Choisissez un nouveau code parent"},
	"forgot_code_changed": {"en": "The code is changed. Enter the new code to go on.",
			"fr": "Le code est modifié. Saisissez le nouveau code pour continuer."},
	"wait": {"en": "Too many tries. Wait {s} s.", "fr": "Trop d'essais. Patientez {s} s."},
	"time_left_session": {"en": "Time left: {t}", "fr": "Temps restant : {t}"},
	"time_left_bedtime": {"en": "Slimes wake in {t}", "fr": "Réveil des slimes dans {t}"},
	"no_session": {"en": "No session running", "fr": "Aucune session en cours"},
	"close": {"en": "Close", "fr": "Fermer"},
	"closing_soon": {"en": "Settings close in {s} s", "fr": "Les réglages se ferment dans {s} s"},
	"change_code": {"en": "Change the code", "fr": "Changer le code"},
	"new_code": {"en": "Enter the new code", "fr": "Saisissez le nouveau code"},
	"new_code_again": {"en": "Enter the new code again", "fr": "Saisissez de nouveau le nouveau code"},
	"codes_differ": {"en": "The two codes differ. Start again.", "fr": "Les deux codes diffèrent. Recommencez."},
	"code_changed": {"en": "The code is changed.", "fr": "Le code est modifié."},
	"back": {"en": "Back", "fr": "Retour"},
	"delete_save": {"en": "Delete a level's save:", "fr": "Effacer la sauvegarde d'un niveau :"},
	"level_name": {"en": "Level {id}", "fr": "Niveau {id}"},
	"delete_confirm": {"en": "This erases all progress in {level}. The session goes on. Delete it?",
			"fr": "Cela efface toute la progression de {level}. La session continue. L'effacer ?"},
	"delete_yes": {"en": "Yes, delete", "fr": "Oui, effacer"},
	"delete_no": {"en": "No", "fr": "Non"},
	"save_deleted": {"en": "{level}: save deleted.", "fr": "{level} : sauvegarde effacée."},
	"delete_failed": {"en": "Deleting the save failed.", "fr": "L'effacement de la sauvegarde a échoué."},
	"next": {"en": "Next", "fr": "Suivant"},
	"setup_done": {"en": "Finish", "fr": "Terminer"},
	"setup_step": {"en": "Step {n} of {total}", "fr": "Étape {n} sur {total}"},
	"setup_welcome_title": {"en": "Welcome", "fr": "Bienvenue"},
	"setup_welcome": {"en": "This game is for your child, who sees no text in it. Along the top of the screen are the "
			+ "parent buttons: wake early, leave and settings. Each asks for a parent code, which you choose now.",
			"fr": "Ce jeu est pour votre enfant, qui n'y voit aucun texte. En haut de l'écran se trouvent les "
			+ "boutons parent : réveiller, quitter et réglages. Chacun demande un code parent, que vous allez "
			+ "choisir maintenant."},
	"setup_code_title": {"en": "The parent code", "fr": "Le code parent"},
	"setup_code": {"en": "Choose a 6-digit parent code", "fr": "Choisissez un code parent à 6 chiffres"},
	"setup_code_again": {"en": "Enter the code again", "fr": "Saisissez de nouveau le code"},
	"setup_forgotten_title": {"en": "If you forget the code", "fr": "Si vous oubliez le code"},
	"setup_forgotten": {"en": "Tap \"Forgot the code?\" when the code is asked: the phone's own screen lock (PIN, "
			+ "pattern or fingerprint) then lets you set a new code. On a phone with no screen lock, the only way "
			+ "out is to clear the app's data in Android settings, and that erases all progress.",
			"fr": "Touchez « Code oublié ? » quand le code est demandé : le verrouillage de l'écran du téléphone "
			+ "(code, schéma ou empreinte) vous permet alors de choisir un nouveau code. Sur un téléphone sans "
			+ "verrouillage de l'écran, la seule solution est d'effacer les données de l'application dans les "
			+ "paramètres d'Android, ce qui efface toute la progression."},
	"setup_pinning_title": {"en": "Screen pinning", "fr": "Épinglage de l'écran"},
	"setup_pinning": {"en": "Each time the game opens, it asks Android to pin the screen, so your child can't leave "
			+ "it. Android asks you to confirm every time. Without pinning, the back gesture and the home button "
			+ "leave the game. We recommend turning on \"Ask for PIN before unpinning\" in Android settings. To "
			+ "show the parent buttons, tap the band along the top of the screen.",
			"fr": "À chaque ouverture, le jeu demande à Android d'épingler l'écran, pour que votre enfant ne "
			+ "puisse pas en sortir. Android vous demande de confirmer à chaque fois. Sans épinglage, le geste "
			+ "retour et le bouton d'accueil quittent le jeu. Nous vous recommandons d'activer « Demander le "
			+ "code PIN avant d'annuler l'épinglage » dans les paramètres d'Android. Pour afficher les boutons "
			+ "parent, touchez la bande en haut de l'écran."},
}

## When "en" or "fr", language() answers it instead of the phone's language
## (a seam for tests and tools; "" = the phone's). Set it before the parent
## layer is built: the surfaces read the language when they are made.
static var language_override := ""


## The language of the parent surfaces: "fr" on a phone set to French, else
## "en" (or language_override when set; an unknown one is refused loudly).
static func language() -> String:
	if language_override != "":
		assert(language_override in LANGUAGES, "ParentText.language_override: unknown language '%s'" % language_override)
		return language_override
	return "fr" if OS.get_locale_language() == "fr" else "en"


## The text of `key` in `lang`. An unknown key or language is refused loudly
## (a caller's bug) and gives "".
static func text(key: String, lang: String) -> String:
	if not TABLE.has(key):
		push_error("ParentText.text: unknown key '%s'" % key)
		return ""
	if not lang in LANGUAGES:
		push_error("ParentText.text: unknown language '%s'" % lang)
		return ""
	return TABLE[key][lang]


## `ms` as "m:ss" (754000 -> "12:34"), whole seconds rounded up so "0:00"
## shows only at the end; a negative reads "0:00".
static func time_left(ms: int) -> String:
	var seconds := ceili(maxi(ms, 0) / 1000.0)
	return "%d:%02d" % [seconds / 60, seconds % 60]
