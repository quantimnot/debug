#****h* debug/nimgdb
## PURPOSE
##   GDB frontend with optional Nim symbol translation and filtering
## SEE ALSO
#*   - [docgen]( href:nimgdb.html )
#* TODO
#*   - add test for entitled gdb on macos
#*   - add proc to entitle gdb on macos
#******

import std/[
  os, sequtils, strutils, tables, locks,
  tempfiles, streams, pegs, options, tables]

import pkg/cligen
import pkg/platforms
import pkg/procs

#****if* nimgdb/info
template info(msg: string) =
  ## PURPOSE
  ##   Write formatted info `msg` to `stderr`.
  stderr.writeLine "info: " & msg
#******

#****if* nimgdb/fatal
template fatal(msg: string) =
  ## PURPOSE
  ##   Write formatted fatal `msg` to `stderr` and quit with error return code.
  stderr.writeLine "error: " & msg
  quit 1
#******

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
  gdbNimPy = staticRead "formatters/nim-gdb.py"
  debuggerPy = staticRead "gdb.py"
  gdbinit = staticRead "gdbinit"
  sleepMsDur {.intdefine.} = 500

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
  OOBRecKind* = enum
    Async, Stream
  AsyncRecKind* = enum
    Exec, Status, Notify
  ResultClass* = enum
    Done, Running, Connected, Error, Exit
  StreamRecKind* = enum
    Console, Target, Log
  AsyncOutputKind* = enum
    Stopped
  ValueKind* = enum
    Const, List, Tuple
  Value* = object
    case kind*: ValueKind
    of Const:
      strVal*: string
    of List:
      listVal*: seq[Value]
    of Tuple:
      tupleVal*: Table[string, Value]
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
    of Stream:
      strmVal*: StreamRec
  ResultRec* = object
  GdbOutput* = object
    oob*: seq[OOBRec]
    res*: Option[ResultRec]
  #****t* nimgdb/GdbInstance
  GdbInstance* = ref object
    ## PURPOSE
    ##   Holds synchronization details for each GDB instance.
    thread*: Thread[(seq[string], ptr GdbInstance)]
    started*: Cond
    stdinLock*: Lock
    gdb*: Gdb
    stdinChan*: Channel[string]
  #******

proc `=copy`(a: var GdbObj, b: GdbObj) {.error.}

var
  gdbInstances*: seq[GdbInstance]
  stop = false

proc newGdbMiParser*(): owned GdbMiParser {.raises: [ValueError, Exception].} =
  GdbMiParser(peg: parsePeg(gdbMiPeg, "gdbMi"))

#****f* nimgdb/parse
proc parse*[T](parser: GdbMiParser, resp: string): Option[T] =
  ## PURPOSE
  ##   Parse GDB's output
  var match: string
  var r: Option[T]
  let miParser = parser.peg.eventParser:
    pkNonTerminal:
      leave:
        if length > 0:
          match = s.substr(start, start+length-1)
          # echo p.nt.name
          case p.nt.name
    #       # of "console_stream_output":
    #       #   echo match
    #       # of "result_record":
    #       #   echo match
          of "output":
            r = some match
  let parsedLen = miParser(resp)
  r
#******

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
  gdb.stdin.write "-gdb-set mi-async on\n"
  gdb.stdin.flush

proc start*(gdb: var Gdb, sync: var GdbInstance) {.gcsafe.} =
  gdb.start
  sync.started.signal
  sync.gdb = gdb
  echo $cast[int](sync)

proc eventLoop*(gdb: Gdb, sync: GdbInstance) {.gcsafe.} =
  echo $gdb.`proc`.monitor

proc gdbThread*(args: (seq[string], ptr GdbInstance)) {.gcsafe.} =
  var gdb = initGdb(args[0], args[1][])
  gdb.start args[1][]
  gdb.eventLoop args[1][]

proc run*(gdb: Gdb, all, start = false, threadGroup = none(int)): bool =
  var cmd = "-exec-run"
  if all: cmd &= " --all"
  elif threadGroup.isSome:
    cmd &= " --thread-group " & $threadGroup.get
  if start: cmd &= " --start"
  gdb.stdin.writeLine cmd
  gdb.stdin.flush

proc exit*(gdb: Gdb) =
  let cmd = "-gdb-exit"
  gdb.stdin.writeLine cmd
  gdb.stdin.flush

proc nimgdb(args: seq[string]) =
  # gdbCb args, cb
  var i = GdbInstance()
  i.initGdbSync
  gdbInstances.add i
  createThread(gdbInstances[0].thread, gdbThread, (args, gdbInstances[0].addr))
  gdbInstances[0].started.wait gdbInstances[0].stdinLock
  discard gdbInstances[0].gdb.run
  gdbInstances[0].thread.joinThread()

proc ctrlc() {.noconv.} =
  stop = true
  for i in gdbInstances:
    i.gdb.exit
setControlCHook(ctrlc)

when isMainModule:
  when defined test:
    import std/unittest
    suite "parse MI":
      setup:
        let parser = newGdbMiParser()
      test "errors":
        check:
          parse[string](parser,
            "^error\n(gdb)\n").isSome
          parse[string](parser,
            "^error,msg=\"Undefined MI command: rubbish\"\n(gdb)\n").isSome
  else:
    dispatch nimgdb
