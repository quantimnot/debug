#****h* debug/debug
## TODO
##   - [ ]
#******
import std/[sets, strutils]
export sets

#****ic* debug/debug
const debug {.strdefine.}: string = ""
## PURPOSE
##   Holds the debug tags that enable debug code.
#******

#****c* debug/debugTags
## PURPOSE
##   Holds the debug tags that enable debug code.
## DESCRIPTION
##   The debug tags are set at compilation like `-d:debug=tag0,tag1,...`.
##   The default tag is 'true', which means everything should be enabled.
const debugTags* = (
  proc(): HashSet[string] =
    if debug.len == 0 or debug == "true":
      return ["*"].toHashSet
    else:
      return debug.split(',').toHashSet
)()
#******

#****f* debug/inDebugTag
## PURPOSE
##   Tests whether any tag in a set is contained in the set of debug tags.
proc inDebugTag*(tags: HashSet[string]): bool =
  not disjoint(tags, debugTags)
#******
