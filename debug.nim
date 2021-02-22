#******
#* NOTES
#*   It looks like @timotheecour is making a LLDB plugin:
#*   https://github.com/timotheecour/Nim/issues/599
#* SEE ALSO
#*   - https://internet-of-tomohiro.netlify.app/nim/gdb.en.html
#*   - https://nim-lang.org/blog/2017/10/02/documenting-profiling-and-debugging-nim-code.html
#*   - manual.html#implementation-specific-pragmas-injectstmt-pragma
#******

when defined(debug):
  {.warning: "DEBUG MODE".}
  #from std/posix import [`raise`, SIGTRAP]
# The InjectStmt pragma.
#{.injectStmt: gcInvariants().}

proc isDebuggerPresent*(): bool =
  proc detectUsingSigtrap(): bool =
    # https://www.oreilly.com/library/view/secure-programming-cookbook/0596003943/ch12s13.html
    discard
  ## https://stackoverflow.com/questions/3596781/how-to-detect-if-the-current-process-is-being-run-by-gdb
  discard

template setBreak*(debugSession: string = ""): untyped =
  ## Set a break point at the current line.
  when defined(debug):
    discard
  else: discard

template setTrace*(debugSession: string = "", expr: untyped = nil): untyped =
  ## Set a trace point at the current line.
  ## Evaluate the expression each time the trace is called.
  when defined(debug):
    discard
  else: discard

template setWatch*(debugSession: string = "", expr: untyped = nil): untyped =
  ## Set a watch point for a location in memory.
  ## The expression is evaluated for a symbol or address when the watch is set.
  when defined(debug):
    discard
  else: discard

template bp* = setBreak
template tp* = setTrace
template wp* = setWatch
template dbg*(msg) = debugEcho msg
