#
# Phase 0-E.1: model for ConsentInformation.getPrivacyOptionsRequirementStatus()
#
class_name PrivacyOptionsRequirementStatus
extends RefCounted

enum Status {
	UNKNOWN,
	NOT_REQUIRED,
	REQUIRED,
}

var status: Status


func _init(a_status_string: String = "") -> void:
	if a_status_string == "":
		status = Status.UNKNOWN
	else:
		status = string_to_status(a_status_string)


func to_status_string() -> String:
	return Status.keys()[status]


static func status_to_string(a_status: Status) -> String:
	return Status.keys()[a_status]


static func string_to_status(a_string: String) -> Status:
	if a_string == "" or not Status.has(a_string):
		return Status.UNKNOWN
	return Status[a_string]
