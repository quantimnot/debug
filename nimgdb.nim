#****h* debug/nimgdb
## PURPOSE
##   GDB frontend with optional Nim symbol translation and filtering
## SEE ALSO
#*   - [docgen]( href:nimgdb.html )
#* TODO
#*   - [ ] parse lists
#*   - [ ] create a symbol translator with test (translator acts on streams)
#*   - [ ] connect gdb stdout to translator
#*   - [ ] connect translator to stdout
#*   - [ ] add test for entitled gdb on macos
#*   - [ ] add proc to entitle gdb on macos
#*   - [ ] maybe rename `result` to `kv` or `pair`?
#*   - [X] connect `nimgdb`'s `stdin` to `gdb`'s `stdin`
#******

import std/[
  os, sequtils, strutils, tables, locks,
  tempfiles, streams, pegs, options, macros]

import pkg/prelude/[alias, compare_variant]
import pkg/cligen
import pkg/platforms
import pkg/procs

# TODO
#   [ ] why is this `sets` import needed when it's already imported and reexported debug_logging?
#       I think this worked earlier when `debug_tags` was `debug`.
import debug_tags
from debug_logging import initLogging, fatal

template debug(msg) =
  debug_logging.debug(msg, tags = @["nimgdb"])

# template runtimeAssert*(expr; msg = "") =
#   ## Runtime asserts.
#   ## Used instead of `std/system.doAssert` for custom formatting.
#   if not expr:
#     fatal msg


# template withDir*(dir: string; body): untyped =
#   var curDir = getCurrentDir()
#   try:
#     setCurrentDir dir
#     body
#   finally:
#     setCurrentDir curDir

const
  gdbMiPeg = staticRead "gdb_mi.peg"

type
  GdbMiParser* = object
    peg: Peg
  GdbObj = object
    path*: string
    parser*: GdbMiParser
    args*: seq[string]
    `proc`*: Process
    stdin*: Stream
    stdout*: FileHandle
    stderr*: FileHandle
  Gdb* = ref GdbObj
  Token* = distinct string
  OOBRecKind* {.pure.} = enum
    Async
    Stream
  #****t* nimgdb/StoppedReason
  StoppedReason* {.pure.} = enum
    ## PURPOSE
    ##   Reason the target has stopped.
    ## ATTRIBUTION
    ##   Copyright (C) 1988-2021 Free Software Foundation, Inc.
    ##   Comments are verbatim copies.
    ##   Subject to GNU Free Documentation License, Version 1.3 or any later version
    ##   Derived/copied from:
    ##     https://sourceware.org/gdb/current/onlinedocs/gdb/GDB_002fMI-Async-Records.html#GDB_002fMI-Async-Records
    #* SEE ALSO
    #*   href:nimgdb.html#StoppedReason
    #* ENUM VALUES
    BreakpointHit = "breakpoint-hit"
    ## A breakpoint was reached.
    WatchpointTrigger = "watchpoint-trigger"
    ## A watchpoint was triggered.
    ReadWatchpointTrigger = "read-watchpoint-trigger"
    ## A read watchpoint was triggered.
    AccessWatchpointTrigger = "access-watchpoint-trigger"
    ## An access watchpoint was triggered.
    FunctionFinished = "function-finished"
    ## An -exec-finish or similar CLI command was accomplished.
    LocationReached = "location-reached"
    ## An -exec-until or similar CLI command was accomplished.
    WatchpointScope = "watchpoint-scope"
    ## A watchpoint has gone out of scope.
    EndSteppingRange = "end-stepping-range"
    ## An -exec-next, -exec-next-instruction, -exec-step, -exec-step-
    ## instruction or similar CLI command was accomplished.
    ExitedSignalled = "exited-signalled"
    ## The inferior exited because of a signal.
    Exited = "exited"
    ## The inferior exited.
    ExitedNormally = "exited-normally"
    ## The inferior exited normally.
    SignalReceived = "signal-received"
    ## A signal was received by the inferior.
    SolibEvent = "solib-event"
    ## The inferior has stopped due to a library being loaded or unloaded.
    ## This can happen when stop-on-solib-events (see Files) is set or when
    ## a catch load or catch unload catchpoint is in use (see Set Catchpoints).
    Fork = "fork"
    ## The inferior has forked. This is reported when catch fork
    ## (see Set Catchpoints) has been used.
    Vfork = "vfork"
    ## The inferior has vforked. This is reported in when catch vfork
    ## (see Set Catchpoints) has been used.
    SyscallEntry = "syscall-entry"
    ## The inferior entered a system call. This is reported when catch syscall
    ## (see Set Catchpoints) has been used.
    SyscallReturn = "syscall-return"
    ## The inferior returned from a system call. This is reported when catch
    ## syscall (see Set Catchpoints) has been used.
    Exec = "exec"
    ## The inferior called exec. This is reported when catch exec
    ## (see Set Catchpoints) has been used.
  #******
  #****t* nimgdb/AsyncRecKind
  AsyncRecKind* {.pure.} = enum
    ## ATTRIBUTION
    ##   Copyright (C) 1988-2021 Free Software Foundation, Inc.
    ##   Comments are verbatim copies.
    ##   Subject to GNU Free Documentation License, Version 1.3 or any later version
    ##   Derived/copied from:
    ##     https://sourceware.org/gdb/current/onlinedocs/gdb/GDB_002fMI-Result-Records.html#GDB_002fMI-Result-Records
    #* SEE ALSO
    #*   href:nimgdb.html#AsyncRecKind
    #* ENUM VALUES
    Exec
    Status
    Notify
  #******
  #****t* nimgdb/ResultKind
  ResultKind* {.pure.} = enum
    ## PURPOSE
    ##   Reason the target has stopped.
    ## ATTRIBUTION
    ##   Copyright (C) 1988-2021 Free Software Foundation, Inc.
    ##   Comments are verbatim copies.
    ##   Subject to GNU Free Documentation License, Version 1.3 or any later version
    ##   Derived/copied from:
    ##     https://sourceware.org/gdb/current/onlinedocs/gdb/GDB_002fMI-Result-Records.html#GDB_002fMI-Result-Records
    #* SEE ALSO
    #*   href:nimgdb.html#ResultKind
    #* ENUM VALUES
    Done = "done"
    ## The synchronous operation was successful, results are the return values.
    Running = "running"
    ## This result record is equivalent to ‘^done’. Historically, it was
    ## output instead of ‘^done’ if the command has resumed the target.
    ## This behaviour is maintained for backward compatibility, but all
    ## frontends should treat ‘^done’ and ‘^running’ identically and rely
    ## on the ‘*running’ output record to determine which threads are resumed.
    Connected = "connected"
    ## GDB has connected to a remote target.
    Error = "error"
    ## The operation failed.
    ## The msg=c-string variable contains the corresponding error message.
    ## If present, the code=c-string variable provides an error code on which
    ## consumers can rely on to detect the corresponding error condition.
    ## At present, only one error code is defined: ‘"undefined-command"’
    ## Indicates that the command causing the error does not exist.
    ## SEE ALSO
    ##   `ErrorCode`
    Exit = "exit"
    ## GDB has terminated.
  #******
  #****t* nimgdb/ErrorCode
  ErrorCode* {.pure.} = enum
    ## PURPOSE
    ##   Enum that represents the error kind.
    ## ATTRIBUTION
    ##   Copyright (C) 1988-2021 Free Software Foundation, Inc.
    ##   Some comments are verbatim copies.
    ##   Subject to GNU Free Documentation License, Version 1.3 or any later version
    ##   Derived/copied from:
    ##     https://sourceware.org/gdb/current/onlinedocs/gdb/GDB_002fMI-Result-Records.html#GDB_002fMI-Result-Records
    #* SEE ALSO
    #*   href:nimgdb.html#ErrorCode
    #* ENUM VALUES
    Unknown = ""
    ## The default error code whenever a code is not defined.
    UndefinedCommand = "undefined-command"
    ## Indicates that the command causing the error does not exist.
  #******
  #****t* nimgdb/Error
  Error* = object
    ## PURPOSE
    ##   Represents an error returned by GDB.
    ## SEE ALSO
    ##   https://sourceware.org/gdb/current/onlinedocs/gdb/GDB_002fMI-Result-Records.html#GDB_002fMI-Result-Records
    #*   href:nimgdb.html#Error
    #* FIELDS
    msg*: string
    ## The error message.
    code*: ErrorCode
    ## The error code. Defaults to `Unknown`. See `ErrorCode`_.
  #******
  StreamRecKind* {.pure.} = enum
    Console
    Target
    Log
  AsyncOutputKind* {.pure.} = enum
    Stopped
  ValueKind* {.pure.} = enum
    Const
    ValueList
    ResultList
    Tuple
  # ListKind* {.pure.} = enum
  #   Value
  #   Result
  Tuple* = Table[string, Value]
  # ListValue* = object
  #   case kind*: ListValueKind
  #   of ListValueKind.Value:
  #     values*: seq[Value]
  #   of ListValueKind.Result:
  #     results*: seq[Result]
  List* = seq[Value]
  Value* = object
    case kind*: ValueKind
    of ValueKind.Const:
      `const`*: string
    of ValueKind.ValueList:
      values*: List
    of ValueKind.ResultList:
      results*: List
    of ValueKind.Tuple:
      `tuple`*: Tuple
  Result* = object
    key*: string
    val*: Value
  AsyncOutput* = object
    token*: Option[Token]
    kind*: AsyncOutputKind
    results*: seq[Result]
  AsyncRec* = object
    kind*: AsyncRecKind
    val*: AsyncOutput
  StreamRec* = object
    kind*: StreamRecKind
    val*: string
  OOBRec* = object
    case kind*: OOBRecKind
    of Async:
      asyncVal*: AsyncRec
    of OOBRecKind.Stream:
      strmVal*: StreamRec
  ResultRec* = object
    token*: Option[Token]
    kind*: ResultKind
    results*: seq[Result]
  Output* = object
    oob*: seq[OOBRec]
    res*: Option[ResultRec]
  #****t* nimgdb/GdbInstance
  GdbInstance* = ref object
    ## PURPOSE
    ##   Holds synchronization details for each GDB instance.
    thread*: Thread[(seq[string], ptr GdbInstance, Handler, Handler)]
    started*: Cond
    stdinLock*: Lock
    gdb*: Gdb
    stdinChan*: Channel[string]
  #******

proc `=copy`(a: var GdbObj, b: GdbObj) {.error.}

# proc `==`*(a,b: ListValue): bool = compareVariant(a,b)
proc `==`*(a,b: Value): bool = compareVariant(a,b)

var
  gdbInstances*: seq[GdbInstance]
  stop = false

#****f* nimgdb/newGdbMiParser
proc newGdbMiParser*(): owned GdbMiParser {.raises: [ValueError, Exception].} =
  ## PURPOSE
  ##   Construct a new GDB MI parser.
  GdbMiParser(peg: parsePeg(gdbMiPeg, "gdbMi"))
#******

#****f* nimgdb/parse
proc parse*(parser: GdbMiParser, resp: string): Option[Output] =
  ## PURPOSE
  ##   Parse GDB's output
  template debug(msg) =
    debug_logging.debug(msg, tags = @["nimgdb_parse"])
  var
    possible: seq[string]
    match: string
    tupleDepth: int
    listDepth: int
    listVal: List
    valLists: seq[seq[Value]]
    resLists: seq[seq[Result]]
    tupleVal: Tuple
    value: Value
    res: Result
    resultPairs: seq[Result]
    results: seq[Result]
    token: Token
    resRec: ResultRec
    o: Output
    r: Option[Output]
  let miParser = parser.peg.eventParser:
    pkNonTerminal:
      enter:
        debug "? " & p.nt.name
        case p.nt.name
        of "tuple":
          possible.add p.nt.name
          tupleDepth.inc
          # debug "tupleDepth start " & $tupleDepth
        of "value_list":
          valLists.add @[]
          possible.add p.nt.name
          listDepth.inc
          # debug "listDepth start " & $listDepth
        of "empty_list":
          possible.add p.nt.name
        of "result_list":
          resLists.add @[]
          possible.add p.nt.name
          listDepth.inc
        of "list":
          listDepth.inc
          # possible.add "list"
        of "result":
          possible.add p.nt.name
      leave:
        if length > 0:
          match = s.substr(start, start+length-1)
          debug "= " & p.nt.name
          case p.nt.name
          of "token":
            token = match.Token
          of "const":
            value.`const` = match.strip(chars = {'"'})
          of "tuple":
            possible.delete(possible.len-1)
            # debug "tupleDepth finish " & $tupleDepth
            debug $results.len
            debug $results
            if tupleDepth > 0:
              tupleDepth.dec
              value.kind = ValueKind.Tuple
              value.`tuple` = tupleVal
              tupleVal.clear
              debug "tupleVal clear"
          of "list":
            # possible.delete(possible.len-1)
            debug $possible
            # NOTE
            #   A list is either empty, contains only values, or contains only results (pairs).
            debug "listDepth finish " & $listDepth
            # if listDepth > 0:
            #   listDepth.dec
            #   value.kind = ValueKind.List
            #   value.`list` = listVal
            #   # listVal.clear
            #   debug "listVal clear"
            # value.`list` = listVal
          of "value_list":
            possible.delete(possible.len-1)
            if listDepth > 0:
              listDepth.dec
              value.kind = ValueKind.ValueList
              value.values = valLists.pop
              # listVal.clear
              debug "listVal clear"
            # value.`list` = listVal
          of "variable":
            resultPairs.add Result(key: match)
            debug $possible
            debug $resultPairs
          of "value":
            debug $possible
            case possible[^1]
            of "value_list":
              valLists[^1].add value
              echo $valLists
            of "result_list":
              resLists[^1].add res
              echo $resLists
            of "empty_list":
              resultPairs[^1].val.kind = ValueKind.ValueList
              resultPairs[^1].val.values = @[]
              echo $resultPairs
            else:
              resultPairs[^1].val = value
              debug $resultPairs
            value.reset
            debug "value reset"
          of "result":
            debug $possible
            let v = resultPairs.pop
            case possible[^1]
            of "result_list":
              resLists[^1].add v
            of "tuple":
              tupleVal[v.key] = v.val
            else:
              results.add v
            possible.delete(possible.len-1)
            # if tupleDepth > 0:
            #   tupleVal[v.key] = v.val
            # else:
            #   results.add v
            # resultPair.reset
            # debug "resultPair reset"
          of "result_class":
            case match
            of $ResultKind.Done:
              resRec.kind = ResultKind.Done
            of $ResultKind.Running:
              # For the reason this sets `Done` instead of `Running`,
              # see https://sourceware.org/gdb/current/onlinedocs/gdb/GDB_002fMI-Result-Records.html#GDB_002fMI-Result-Records
              resRec.kind = ResultKind.Done
            of $ResultKind.Connected:
              resRec.kind = ResultKind.Connected
            of $ResultKind.Error:
              resRec.kind = ResultKind.Error
            of $ResultKind.Exit:
              resRec.kind = ResultKind.Exit
            else:
              fatal "unhandled result kind"
          of "result_record":
            resRec.results = results
            o.res = some resRec
            resRec.reset
            debug "resRec reset"
          of "output":
            r = some o
        else:
          debug "! " & p.nt.name
          case p.nt.name
          of "tuple":
            tupleDepth.dec
            possible.delete(possible.len-1)
          of "list":
            listDepth.dec
            # possible.delete(possible.len-1)
          of "value_list", "result_list", "empty_list":
            possible.delete(possible.len-1)

  let parsedLen = miParser(resp) # TODO: do something with this result
  debug $r
  r
#******

func getError*(resRec: ResultRec): Option[Error] =
  if resRec.kind == ResultKind.Error:
    result = some Error()
    if resRec.results.len > 0:
      if resRec.results[0].key == "msg":
        doAssert resRec.results[0].val.kind == ValueKind.Const
        result.get.msg = resRec.results[0].val.`const`
      if resRec.results.len > 1 and resRec.results[1].key == "code":
        case resRec.results[1].val.`const`
        of $ErrorCode.UndefinedCommand:
          result.get.code = ErrorCode.UndefinedCommand
        else:
          debug "failed to handle error code: " & resRec.results[1].val.`const`

func getError*(output: Output): Option[Error] =
  if output.res.isSome:
    return output.res.get.getError

func getError*(output: Option[Output]): Option[Error] =
  if output.isSome:
    return output.get.getError

func initGdbSync*(sync: var GdbInstance) =
  sync.started.initCond
  sync.stdinLock.initLock

proc initGdb*(args: openArray[string]): Gdb =
  result = Gdb()
  result.path = findExe "gdb"
  result.parser = newGdbMiParser()
  result.args = @["-i", "mi"]
  result.args.add(args)

proc initGdb*(args: openArray[string], sync: var GdbInstance): Gdb {.gcsafe.} =
  result = initGdb args

proc start*(gdb: var Gdb) =
  gdb.`proc` = gdb.path.startProcess(
    args = gdb.args,
    options = {}
  )
  gdb.stdin = gdb.`proc`.inputStream
  gdb.stdout = gdb.`proc`.outputHandle
  gdb.stderr = gdb.`proc`.errorHandle

proc start*(gdb: var Gdb, sync: var GdbInstance) {.gcsafe.} =
  gdb.start
  sync.started.signal
  sync.gdb = gdb

proc eventLoop*(gdb: Gdb, sync: GdbInstance,
    stdoutHandler, stderrHandler: Handler = nil)
    {.effectsOf: [stdoutHandler, stderrHandler].} =
  echo $gdb.`proc`.monitor(stdoutHandler, stderrHandler)

proc gdbThread*(args: (seq[string], ptr GdbInstance, Handler, Handler)) {.gcsafe.} =
  var gdb = initGdb(args[0], args[1][])
  gdb.start args[1][]
  {.cast(gcsafe).}:
    gdb.eventLoop args[1][], args[2], args[3]

#****f* nimgdb/write
proc write*(gdb: Gdb, cmd: string) =
  ## PURPOSE
  ##   Writes `cmd` to GDB input.
  echo "<- " & cmd
  gdb.stdin.write cmd
  gdb.stdin.flush
#******

#****f* nimgdb/run
proc run*(gdb: Gdb, all, start = false, threadGroup = none(int)): bool =
  ## PURPOSE
  ##   Run the inferior.
  var cmd = "-exec-run"
  if all: cmd &= " --all"
  elif threadGroup.isSome:
    cmd &= " --thread-group " & $threadGroup.get
  if start: cmd &= " --start"
  cmd &= '\n'
  gdb.write cmd
#******

#****f* nimgdb/exit
proc exit*(gdb: Gdb) =
  ## PURPOSE
  ##   Close the GDB session.
  gdb.write "-gdb-exit\n"
#******

#****f* nimgdb/preRunOrAttachCmds
func preRunOrAttachCmds*: string =
  ## PURPOSE
  ##   Return commands to setup the debugger *before* it runs or attaches to a
  ##   target.
  ## SEE ALSO
  ##   Debugging with GDB: 27.3.2 Asynchronous command execution and non-stop mode
  # https://sourceware.org/gdb/current/onlinedocs/gdb/Asynchronous-and-non_002dstop-modes.html#Asynchronous-and-non_002dstop-modes
  result &= "-gdb-set mi-async on\n"
  # https://sourceware.org/gdb/current/onlinedocs/gdb/Non_002dStop-Mode.html#Non_002dStop-Mode
  result &= "-gdb-set non-stop on\n"
#******

#****f* nimgdb/newDefaultGdbOptions
func newDefaultGdbOptions*: string =
  ## PURPOSE
  ##   Return default options for a GDB session.
  ##   Can be set after running or attaching to a target.
  discard
#******

#****if* nimgdb/ctrlc
proc ctrlc() {.noconv.} =
  ## PURPOSE
  ##   Cntrl-C signal handler
  ##   Closes each GDB instance.
  ## SEE ALSO
  ##   `setControlCHook`
  stop = true
  for i in gdbInstances:
    i.gdb.exit
#******

#****f* nimgdb/nimgdb
proc nimgdb*(args: seq[string],
    preRunOrAttachCmds = preRunOrAttachCmds(),
    dbgOpts = newDefaultGdbOptions()) =
  ## PURPOSE
  ##   Instantiates a debugger session.
  ##   Passes `args` verbatim to the debugger programm.
  ##   Checks and sets default debugger options.
  ## SEE ALSO
  ##   `preRunOrAttachCmds`
  ##   `newDefaultGdbOptions`
  initLogging()
  var i = GdbInstance()
  i.initGdbSync
  gdbInstances.add i
  alias gdbSync, gdbInstances[0]
  proc p(o: string) {.nimcall.} = stdout.write o
  setControlCHook(ctrlc)
  createThread(gdbSync.thread, gdbThread, (args, gdbSync.addr, p, p))
  gdbSync.started.wait gdbSync.stdinLock
  # TODO: assert that target is not attached or running
  gdbSync.gdb.write preRunOrAttachCmds
  gdbSync.gdb.write dbgOpts
  # discard gdbSync.gdb.run
  while not stdin.endOfFile:
    gdbSync.gdb.write stdin.readLine & '\n'
  gdbSync.thread.joinThread()
#******

when isMainModule:
  when defined test:
    initLogging()
    import std/[tempfiles, unittest]
    # import fusion/scripting
    template checkParsed(i) = check parse(parser, i).isSome
    suite "MI parser":
      setup:
        let parser = newGdbMiParser()
      test "command success responses":
        var success = parse(parser, "^done,key=\"val\"\n(gdb)\n")
        check:
          success.isSome
          success.get.res.isSome
          success.get.res.get.kind == ResultKind.Done
          success.get.res.get.results.len == 1
          success.get.res.get.results[0].key == "key"
          success.get.res.get.results[0].val.`const` == "val"
        success = parse(parser, "^done\n(gdb)\n")
        check:
          success.isSome
          success.get.res.isSome
          # For the reason this checks for `Done` instead of `Running`,
          # see https://sourceware.org/gdb/current/onlinedocs/gdb/GDB_002fMI-Result-Records.html#GDB_002fMI-Result-Records
          success.get.res.get.kind == ResultKind.Done
        success = parse(parser, "^running\n(gdb)\n")
        check:
          success.isSome
          success.get.res.isSome
          success.get.res.get.kind == ResultKind.Done
        success = parse(parser, "^connected\n(gdb)\n")
        check:
          success.isSome
          success.get.res.isSome
          success.get.res.get.kind == ResultKind.Connected
        success = parse(parser, "^exit\n(gdb)\n")
        check:
          success.isSome
          success.get.res.isSome
          success.get.res.get.kind == ResultKind.Exit
      test "command error responses":
        var err = parse(parser, "^error,msg=\"Undefined MI command: rubbish\",code=\"undefined-command\"\n(gdb)\n").getError
        check:
          err.isSome
          err.get.code == ErrorCode.UndefinedCommand
          err.get.msg == "Undefined MI command: rubbish"
        err = parse(parser, "^error,msg=\"Undefined MI command: rubbish\"\n(gdb)\n").getError
        check:
          err.isSome
          err.get.code == ErrorCode.Unknown
          err.get.msg == "Undefined MI command: rubbish"
        err = parse(parser, "^error,msg=\"Undefined MI command: rubbish\"\n(gdb)\n").getError
        check:
          err.isSome
          err.get.code == ErrorCode.Unknown
        err = parse(parser, "^done\n(gdb)\n").getError
        check err.isNone
      test "tuple values":
        var success = parse(parser, "^done,key={}\n(gdb)\n")
        check:
          success.isSome
          success.get.res.isSome
          success.get.res.get.results.len == 1
          success.get.res.get.results[0].key == "key"
          success.get.res.get.results[0].val.kind == ValueKind.Tuple
          success.get.res.get.results[0].val.`tuple`.len == 0
        success = parse(parser, "^done,key={key=\"val\"}\n(gdb)\n")
        check:
          success.isSome
          success.get.res.isSome
          success.get.res.get.results.len == 1
          success.get.res.get.results[0].key == "key"
          success.get.res.get.results[0].val.kind == ValueKind.Tuple
          success.get.res.get.results[0].val.`tuple`.len == 1
          success.get.res.get.results[0].val.`tuple`["key"].`const` == "val"
        success = parse(parser, "^done,a={b={c=\"d\"}}\n(gdb)\n")
        check:
          success.isSome
          success.get.res.isSome
          success.get.res.get.results.len == 1
          success.get.res.get.results[0].key == "a"
          success.get.res.get.results[0].val.kind == ValueKind.Tuple
          success.get.res.get.results[0].val.`tuple`.len == 1
          success.get.res.get.results[0].val.`tuple`["b"].`tuple`.len == 1
          success.get.res.get.results[0].val.`tuple`["b"].`tuple`["c"].`const` == "d"
        success = parse(parser, "^done,a={b={c=\"d\"},e=\"f\"}\n(gdb)\n")
        check:
          success.isSome
          success.get.res.isSome
          success.get.res.get.results.len == 1
          success.get.res.get.results[0].key == "a"
          success.get.res.get.results[0].val.kind == ValueKind.Tuple
          success.get.res.get.results[0].val.`tuple`.len == 2
          success.get.res.get.results[0].val.`tuple`["b"].`tuple`.len == 1
          success.get.res.get.results[0].val.`tuple`["b"].`tuple`["c"].`const` == "d"
          success.get.res.get.results[0].val.`tuple`["e"].`const` == "f"
      test "list values":
        var success = parse(parser, "^done,key=[]\n(gdb)\n")
        check:
          success.isSome
          success.get.res.isSome
          success.get.res.get.results.len == 1
          success.get.res.get.results[0].key == "key"
          success.get.res.get.results[0].val.kind == ValueKind.ValueList
          success.get.res.get.results[0].val.values.len == 0
        success = parse(parser, "^done,key=[\"val\"]\n(gdb)\n")
        check:
          success.isSome
          success.get.res.isSome
          success.get.res.get.results.len == 1
          success.get.res.get.results[0].key == "key"
          success.get.res.get.results[0].val.kind == ValueKind.ValueList
          success.get.res.get.results[0].val.values.len == 1
          success.get.res.get.results[0].val.values[0].`const` == "val"
        success = parse(parser, "^done,a=[\"b\",[\"c\"],{},{d=\"e\"}]\n(gdb)\n")
        check:
          success.isSome
          success.get.res.isSome
          success.get.res.get.results.len == 1
          success.get.res.get.results[0].key == "a"
          success.get.res.get.results[0].val.kind == ValueKind.ValueList
          success.get.res.get.results[0].val.values.len == 4
          success.get.res.get.results[0].val.values[0].`const` == "b"
          success.get.res.get.results[0].val.values[1].kind == ValueKind.ValueList
          success.get.res.get.results[0].val.values[1].values[0].`const` == "c"
          success.get.res.get.results[0].val.values[2].kind == ValueKind.Tuple
          success.get.res.get.results[0].val.values[2].`tuple`.len == 0
          success.get.res.get.results[0].val.values[3].kind == ValueKind.Tuple
          success.get.res.get.results[0].val.values[3].`tuple`.len == 1
          success.get.res.get.results[0].val.values[3].`tuple`["d"].`const` == "e"
        success = parse(parser, "^done,a=[b=\"c\"]\n(gdb)\n")
        check:
          success.isSome
          success.get.res.isSome
          success.get.res.get.results.len == 1
          success.get.res.get.results[0].key == "a"
          success.get.res.get.results[0].val.kind == ValueKind.ResultList
          # success.get.res.get.results[0].val.results.len == 1
          # success.get.res.get.results[0].val.results[0].key == "b"
          # success.get.res.get.results[0].val.results[0].val.`const` == "c"
    # suite "e2e":
    #   setup:
    #     let tmp = createTempDir("debug_gdb", "test_e2e")
    #   teardown:
    #     removeDir tmp
    #   test "load inferior":
    #     check:
    #       false
  else:
    dispatch nimgdb
