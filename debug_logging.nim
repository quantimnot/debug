#****h* debug/logging
## PURPOSE
##   Provides debug logging.
#******
import std/[macros, sets, logging, strutils, os]

import debug_tags
export debug_tags

export
  logging.log, logging.info, logging.notice, logging.warn, logging.error

var consoleLog {.threadvar.}: Logger

template moduleName*: string = instantiationInfo().filename.splitFile.name

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

#****f* logging/debug(string,seq[string])
template debug*(msg: string, tags = @[moduleName]) =
  ## PURPOSE
  ##   Write formatted debug `msg` to `stderr`.
  when debug_tags.inDebugTags(tags):
    {.cast(noSideEffect).}:
      logging.debug msg
#******

#****f* logging/fatal
template fatal*(msg: string) =
  ## PURPOSE
  ##   Write formatted fatal `msg` to `stderr` and quit with error return code.
  logging.fatal msg
  quit 1
#******

when isMainModule:
  when defined test:
    import std/[tempfiles, unittest]
    suite "debug logging":
      test "init":
        initLogging()
        debug "init", tags = @["test"]
