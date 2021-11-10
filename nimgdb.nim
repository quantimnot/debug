#****h* debug/nimgdb
## PURPOSE
##   GDB frontend with optional type translation and filtering
## SEE ALSO
#*   - [docgen]( href:nimgdb.html )
#* TODO
#*   - [ ] connect gdb stdout to translator
#*   - [ ] connect translator to stdout
#*   - [ ] add test for entitled gdb on macos
#*   - [ ] add proc to entitle gdb on macos
#*   - [X] connect `nimgdb`'s `stdin` to `gdb`'s `stdin`
#******
import
  std/[os, sequtils, strutils, tables, locks, tempfiles, streams, options],
  pkg/[platforms, procs],
  pkg/prelude/[alias],
  "."/[debug_mi, debug_logging]

type
  GdbObj = object
    path*: string
    parser*: GdbMiParser
    args*: seq[string]
    `proc`*: Process
    stdin*: Stream
    stdout*: FileHandle
    stderr*: FileHandle
  Gdb* = ref GdbObj
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

var
  gdbInstances*: seq[GdbInstance]
  stop = false

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
    # suite "e2e":
    #   setup:
    #     let tmp = createTempDir("debug_gdb", "test_e2e")
    #   teardown:
    #     removeDir tmp
    #   test "load inferior":
    #     check:
    #       false
  else:
    import pkg/cligen
    dispatch nimgdb
