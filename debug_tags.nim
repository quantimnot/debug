#****h* debug/tags
## TODO
##   - [ ]
#******
import std/[sets, strutils]
export sets

#****id* tags/debug const
const debug {.strdefine.}: string = ""
  ## PURPOSE
  ##   Holds the debug tags that enable debug code.
#******

#****c* tags/debugTags
const debugTags* = (
  proc(): HashSet[string] =
    if debug.len == 0 or debug == "true":
      return ["*"].toHashSet
    else:
      return debug.split(',').toHashSet
)()
  ## PURPOSE
  ##   Holds the debug tags that enable debug code.
  ## DESCRIPTION
  ##   The debug tags are set at compilation like `-d:debug=tag0,tag1,...`.
  ##   The default tag is 'true', which means everything should be enabled.
#******

#****f* tags/inDebugTags
proc inDebugTags*(tags: seq[string]): bool =
  ## PURPOSE
  ##   Tests whether any tag in a set is contained in the set of debug tags.
  # when tags is seq[string]:
  not disjoint(tags.toHashSet, debugTags)
  # elif tags is HashSet[string]:
  #   not disjoint(tags, debugTags)
#******
