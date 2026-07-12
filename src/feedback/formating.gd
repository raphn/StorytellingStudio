extends RefCounted

## Helper to format BBCODE text
class_name Formating

var prefix := ""
var sufix := ""

func apply(to:String) -> String:
	return "%s%s%s" % [prefix, to, sufix]


# ==================== || FORMATINGS ................... || ================== #

static func create(mark:String, value:="") -> Formating:
	var nf := Formating.new()
	
	if value != "":
		nf.prefix = "[%s=%s]" % [mark, value]
		nf.sufix = "[/%s]" % mark
	else:
		nf.prefix = "[%s]" % mark
		nf.sufix = "[/%s]" % mark
	return nf

static func italic_formating() -> Formating: return create("i")

static func bold_formating() -> Formating: return create("b")

static func font_size(size:int) -> Formating: return create("font_size", str(size))

static func color(col:String) -> Formating: return create("color", col)


# ==================== || APPLIED ...................... || ================== #

static func italic(content:String) -> String:
	return italic_formating().apply(content)

static func bold(content:String) -> String:
	return bold_formating().apply(content)

static func bold_italic(content:String) -> String:
	return bold_formating().apply(italic_formating().apply(content))

static func colored(content:String, col:String) -> String:
	return color(col).apply(content)

static func with_color(content:String, col:Color) -> String:
	return color(col.to_html()).apply(content)

static func font_resize(content:String, size:int) -> String:
	return font_size(size).apply(content)
