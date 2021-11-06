## =======================
## Native Debugger Support
## =======================
##
## Some aids for debugging Nim projects with a native debugger.
##
##
## Design
## ======
##
## * each debugger has an extension
##   * some extensions can be embedded into the debuggee
##   * others have to be built as separate files that are loaded by a debugger
## * a debugger ext calls debugger procs inside the debuggee
## * embedded debugger procs can eval expressions in the debugger
##
## Debuggers
## =========
##
## LLDB
## ----
##
##
##
## GDB
## ---
##
##
##
## See also
## --------
##
##
##
## TODO
## ----
##
## *
## *
## *
##

import std/[re]
from std/importutils import privateAccess
import std/typeinfo {.all.}

import pkg/nimpy

let nimTypeRe = re"^([A-Za-z0-9]+)_[A-Za-z0-9]*_+[A-Za-z0-9]*$"

proc debuggerInit {.exportc.} =
  echo "Nim Debugger Runtime ENABLED"

proc debuggerTypeNameFromNimNode(node: int): string {.exportpy.} =
  let n = cast[ptr TNimNode](node)
  privateAccess(typeof(n)) # enables private access in this scope
  $n.name

proc debuggerTypeNameFromMangled(mangled: string): string {.exportpy.} =
  case mangled
  of "NI":
      return "system.int"
  of "NI8":
      return "int8"
  of "NI16":
      return "int16"
  of "NI32":
      return "int32"
  of "NI64":
      return "int64"
  of "NU":
      return "uint"
  of "NU8":
      return "uint8"
  of "NU16":
      return "uint16"
  of "NU32":
      return "uint32"
  of "NU64":
      return "uint64"
  of "NF":
      return "float"
  of "NF32":
      return "float32"
  of "NF64":
      return "float64"
  of "NIM_CHAR":
      return "char"
  of "NCSTRING":
      return "cstring"
  of "NimStringV2", "NimStringDesc":
    return "string"
  of "_Bool", "NIM_BOOL": # see "bool types" in lib/system/nimbase.h
    return "bool"
  else:
    var matches: array[1, string]
    if match($mangled, nimTypeRe, matches, 0):
      case matches[0]
      of "tyObject":
        # var a = toAny(cast[var RootObj](address))
        # for f in a.fields:
        #   echo $f
        return "object"
      # else:
      # of "tySequence": return repr(cast[openArray](address)).cstring
    else:
      return mangled

proc debuggerRepr(kind: cstring, address: pointer): cstring {.exportc.} =
  var matches: array[3, string]
  if match($kind, nimTypeRe, matches, 0):
    case matches[0]
    of "tyObject":
      # var a = toAny(cast[var RootObj](address))
      # for f in a.fields:
      #   echo $f
      echo matches
      return "repr(cast[RootObj](address)).cstring"
    of "NimStringDesc":
      echo matches
      return "repr(cast[string](address)).cstring"
    else:
      echo matches
    # of "tySequence": return repr(cast[openArray](address)).cstring
  else:
    return kind

proc debuggerHint(kind: cstring): cstring {.exportc.} =
  var matches: array[2, string]
  if match($kind, nimTypeRe, matches, 0):
    return matches[0].cstring
  else:
    echo matches
    return kind

#[ const debuggerSection = """
__asm__ (
  ".pushsection __TEXT, debugger\n"
  ".byte 4\n" // python text
  ".byte 0\n"
  ".popsection\n"
);
"""

{.emit: debuggerSection.} ]#

#[ from ast import PNode, safeLen
from renderer import renderTree

proc debuggerRenderTree(node: PNode): string {.exportc.} =
  renderTree node

func debuggerNodeSonsLen(node: PNode): int {.exportc.} =
  safeLen node ]#
