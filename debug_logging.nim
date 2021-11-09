#****h* debug/logging
## TODO
##   - [ ]
#******
import std/[macros, sets, logging, strutils, os]

import "."/debug as dbg

export
  logging.log, logging.info, logging.notice, logging.warn, logging.error

var consoleLog {.threadvar.}: Logger

#****if* logging/lineInfo
proc lineInfo(info: tuple[filename: string, line: int, column: int]): string =
  ## PURPOSE
  ##   Return formatted lineinfo as a string.
  ## DESCRIPTION
  ##   Used for logging.
  ##   Formatted with a leading relative directory so link is clickable in VSCode.
  format($CurDir/"$1($2, $3)", info.filename, info.line, info.column)
#******

#****f* logging/initLogging
proc initLogging*() =
  ## PURPOSE
  ##   Initialize logging for the current thread.
  ## DESCRIPTION
  ##   Different global logging variables such as log filter level are thread
  ##   local variables and need initialized before use in each thread.
  consoleLog = newConsoleLogger(fmtStr="$levelid: ", useStderr = true)
  consoleLog.addHandler
  when defined debug:
    setLogFilter(lvlDebug)
#******

# #****f* logging/traceMsg
# template traceMsg*(msg: string) =
#   ## PURPOSE
#   ##   Write formatted trace `msg` to `stderr`.
#   when defined trace:
#     {.cast(noSideEffect).}:
#       stderr.writeLine format("$1 $2", lineInfo(instantiationInfo()), msg)
# #******

# #****f* logging/trace(sym, msg)
# macro trace*(sym: typed, msg: untyped = nil) =
#   ## PURPOSE
#   ##   Write formatted trace `msg` to `stderr`.
#   echo repr sym.getTypeImpl
#   when defined trace:
#     let id: string = repr sym
#     {.cast(noSideEffect).}:
#       if msg == nil:
#         quote do:
#           stderr.writeLine format("$1 trace($2) = $3",
#             lineInfo(instantiationInfo()), `id`, `sym`)
#       else:
#         quote do:
#           stderr.writeLine format("$1 trace($2) = $3 \"$4\"",
#             lineInfo(instantiationInfo()), `id`, `sym`, `msg`)
# #******

#****f* logging/debug
template debug*(msg: string, tags: HashSet[string] = ["*"].toHashSet) =
  ## PURPOSE
  ##   Write formatted debug `msg` to `stderr`.
  when tags.hasDebugTag:
    {.cast(noSideEffect).}:
      # stderr.writeLine format("$1 debug: $2", lineInfo(instantiationInfo()), msg)
      logging.debug msg
#******

# #****f* logging/info
# template info*(msg: string) =
#   ## PURPOSE
#   ##   Write formatted info `msg` to `stderr`.
#   stderr.writeLine "info: " & msg
# #******

#****f* logging/fatal
template fatal*(msg: string) =
  ## PURPOSE
  ##   Write formatted fatal `msg` to `stderr` and quit with error return code.
  # stderr.writeLine "fatal: " & msg
  logging.fatal msg
  quit 1
#******
