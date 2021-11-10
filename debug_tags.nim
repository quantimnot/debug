#****h* debug/tags
## PURPOSE
##   Scope debug code to specific tags that can be set at compile time.
## EXAMPLE
##   ```sh
##   nim r -d:debug=tag,othertag,anothertag
##   ```
## TODO
##   - [ ] support tag exclusion: `nim r -d:debug=-tagname
##   - [ ] support tag re: `nim r -d:debug=/tag.+/
#******
import std/[sets, strutils]

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

#****f* tags/allTagsEnabled
proc allTagsEnabled*: bool =
  ## PURPOSE
  ##   Returns whether all debug tags are enabled.
  "*" in debugTags
#******

#****f* tags/inDebugTags
proc inDebugTags*(tags: seq[string]): bool =
  ## PURPOSE
  ##   Tests whether any tag in a set is contained in the set of debug tags.
  allTagsEnabled() or not disjoint(tags.toHashSet, debugTags)
#******
