class_name ErrorResult extends RefCounted

var message : String
var cause : ErrorResult

@warning_ignore("shadowed_variable")
func _init(message : String, cause : ErrorResult = null):
    self.message = message
    self.cause = cause

func _to_string():
    if not cause:
        return message

    var result := message
    var c := cause
    var prefix := "\n\n("
    while c:
        result += prefix + cause.message
        prefix += " "
        c = c.cause
    result += ")"
    return result