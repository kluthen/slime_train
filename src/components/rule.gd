class_name Rule
extends Resource
## The rule format the level components share (master spec §5.4): "when this
## object does that, this other object does this". As plain data:
##
##   {"when": {"object": "s1.basket", "event": "full"},
##    "then": {"object": "s1.gate", "action": "open"}}
##
## Objects are named by stable ID. The object that triggers a rule usually
## holds it (a Basket builds its rule from its on_full_* properties); a Level
## can hold extra rules. Every rule is validated when the level loads: both
## objects must be in the level, the "when" object must emit the event
## (its rule_events()) and the "then" object must accept the action (its
## rule_actions()). Executing rules comes with chunk 14.
# @spec-link [[req_interactive_objects_general]]

## The stable ID of the object whose event triggers the rule.
@export var when_object := ""
## The event, one of the "when" object's rule_events() ("full" for a basket).
@export var when_event := ""
## The stable ID of the object that acts.
@export var then_object := ""
## The action, one of the "then" object's rule_actions() ("open" for a gate).
@export var then_action := ""


## A rule: when object `when_id` sends `event`, object `then_id` does
## `action`.
static func make(when_id: String, event: String, then_id: String, action: String) -> Rule:
	var rule := Rule.new()
	rule.when_object = when_id
	rule.when_event = event
	rule.then_object = then_id
	rule.then_action = action
	return rule


## A rule from its plain-data form (see above).
static func from_dict(data: Dictionary) -> Rule:
	var when: Dictionary = data.get("when", {})
	var then: Dictionary = data.get("then", {})
	return make(when.get("object", ""), when.get("event", ""), then.get("object", ""), then.get("action", ""))


## The plain-data form.
func to_dict() -> Dictionary:
	return {"when": {"object": when_object, "event": when_event},
			"then": {"object": then_object, "action": then_action}}


## What is wrong with the rule against `registry` (stable ID -> node), as
## readable errors; empty when both ends exist and understand it.
func validate(registry: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	var label := "rule \"when %s %s, %s %s\"" % [when_object, when_event, then_object, then_action]
	var trigger: Object = registry.get(when_object)
	if trigger == null:
		errors.append("%s: %s isn't in the level" % [label, when_object])
	elif not trigger.has_method("rule_events") or not when_event in trigger.rule_events():
		errors.append("%s: %s has no event '%s'" % [label, when_object, when_event])
	var target: Object = registry.get(then_object)
	if target == null:
		errors.append("%s: %s isn't in the level" % [label, then_object])
	elif not target.has_method("rule_actions") or not then_action in target.rule_actions():
		errors.append("%s: %s has no action '%s'" % [label, then_object, then_action])
	return errors
