#****h* debug/lldb
## SEE ALSO
##   - https://lldb.llvm.org/cpp_reference/classlldb_1_1SBCommandInterpreter.html
##   - [LLDB Homepage]( https://lldb.llvm.org/ )
##   - [LLDB-MI Repo]( https://github.com/lldb-tools/lldb-mi )
##   - [LLDB Tutorial]( https://lldb.llvm.org/use/tutorial.html )
#******

import std/[macros, macrocache, options]


# TODO: move out
type DebuggerApiKind* {.pure.} = enum
  gdbCommandApi
  lldbCppApi
  microsoftCppEngExtApi
type DebuggerObj* = object
#[   case kind*: DebuggerApiKind
  of gdbCommandApi: gdb*: string
  of lldbCppApi: nativeHandle*: pointer
  of microsoftCppEngExtApi: nativeHandle*: pointer ]#
type Debugger* = ref DebuggerObj
# proc `break`(debugger: Debugger)


{.passC: "-std=c++2a -fPIC".} # TODO
{.passC: "-I /Volumes/origin/ws/ports/direct/rdn/org.llvm.llvm/origin.src/lldb/include".} # TODO
{.passL: "/Library/Developer/CommandLineTools/Library/PrivateFrameworks/LLDB.framework/Versions/A/LLDB".} # TODO
{.passL: "-rpath /Library/Developer/CommandLineTools/Library/PrivateFrameworks".}


{.emit: """
#include "lldb/API/SBCommandInterpreter.h"
#include "lldb/API/SBCommandReturnObject.h"
#include "lldb/API/SBDebugger.h"
using namespace lldb;
""".}

const debuggerCommandsToAdd = CacheSeq"debuggerCommandsToAdd"

proc newCommandImpl(name, exec: NimNode; shortHelp, longHelp, completeImpl: NimNode = nil; repeatable: bool = true): NimNode {.compiletime.} =
  expectKind name, nnkIdent
  #expectKind shortHelp, nnkOption
  #expectKind shortHelp, nnkStrLit
  #expectKind body, nnkStmtList

  result = newStmtList()
  let nameStrVal = $name
  let nameObj = ident(name.repr & "Obj")
  let newId = ident("new" & name.repr)
  let execStr = nameStrVal & "Impl"
  let exec = ident(execStr)
  let adapter = """
    struct """ & nameStrVal & """ : public SBCommandPluginInterface {
      virtual bool DoExecute(SBDebugger debugger, char** command, SBCommandReturnObject &result) {
        return """ & execStr & """(debugger, command, result);
      }
    };""" &
    nameStrVal & """ * new""" & nameStrVal & """() { return new """ & nameStrVal & """(); }"""

  result.add quote("@") do:
    proc `@exec`(debugger {.inject.}: SBDebuggerObj,
                         command {.inject.}: ptr cstring,
                         cmdResult {.inject.}: SBCommandReturnObject): bool {.exportc.} =
      @exec
    {.emit: @adapter.}
    type `@nameObj` {.importcpp: @nameStrVal.} = object
    type `@name` = ptr `@nameObj`
    proc `@newId`: `@name` {.importcpp.}
#[ macro newCommandPrefix(name; shortHelp = ""; body: untyped = nil) =
  runnableExamples:
    newCommandPrefix example, "an example":
      newCommand child, "child help":
        echo "childish"
  expectKind name, nnkIdent
  expectKind shortHelp, nnkStrLit
  var prefixedCommands: PrefixedDebuggerCommands
  var found = false
  for commands in debuggerPrefixedCommandsToAdd:
    if commands.name.strVal == name.strVal:
      prefixedCommands = commands
      found = true
  if found:
    prefixedCommands.commands.add ()
  else:
    debuggerPrefixedCommandsToAdd.add (name, none(NimNode), @[])
 ]#
#[ macro addCommand(command: DebuggerCommand): untyped =
  ## Add a new debugger command.
  discard#result = newCommandImpl(name, nil, nil, body)
 ]#
macro newCommand(name, shortHelp, body): untyped =
  ## Define a new debugger command.
  runnableExamples:
    newCommand e, "example":
      for arg in command.args(): echo arg
      return true
  result = newCommandImpl(name, nil, nil, body)
#[   debuggerCommandsToAdd.add (
    name: name,
    exec: exec,
    shortHelp: if shortHelp.strVal.len > 0: some(shortHelp) else: none(NimNode),
    longHelp: if longHelp.strVal.len > 0: some(shortHelp) else: none(NimNode),
    repeatable: repeatable,
    complete: if shortHelp.strVal.len > 0: some(shortHelp) else: none(NimNode),
  ) ]#


type
  SBDebuggerObj {.header: "lldb/API/SBDebugger.h", importcpp: "SBDebugger".} = object
  SBDebugger = ptr SBDebuggerObj
  SBCommandReturnObject {.
    header: "lldb/API/SBCommandReturnObject.h", importcpp: "SBCommandReturnObject".} = object
  SBCommandInterpreterObj {.
    header: "lldb/API/SBCommandInterpreter.h", importcpp: "SBCommandInterpreter".} = object
  SBCommandInterpreter = ptr SBCommandInterpreterObj
  SBCommandObj {.header: "lldb/API/SBCommandInterpreter.h", importcpp: "SBCommand".} = object
  SBCommand = ptr SBCommandObj
  SBCommandPluginInterfaceObj {.header: "lldb/API/SBCommandInterpreter.h", importcpp: "SBCommandPluginInterface".} = object
  SBCommandPluginInterface = ptr SBCommandPluginInterfaceObj

proc GetCommandInterpreter(this: SBDebuggerObj): SBCommandInterpreterObj {.
  header: "lldb/API/SBDebugger.h", importcpp.}
proc AddMultiwordCommand(this: var SBCommandInterpreterObj; name, desc: cstring): SBCommandObj {.
  header: "lldb/API/SBCommandInterpreter.h", importcpp: "#.AddMultiwordCommand(@)".}
proc AddCommand(this: var SBCommandInterpreterObj; name: cstring; impl: SBCommandPluginInterface; desc: cstring): SBCommandObj {.
  header: "lldb/API/SBCommandInterpreter.h", importcpp: "#.AddCommand(@)".}
proc IsValid(this: SBCommandObj): bool {.
  header: "lldb/API/SBCommandInterpreter.h", importcpp: "#.IsValid()".}


macro genPluginEntryPoint: untyped =
  ## Generates `exec` and `complete` procs for each command added with `addDebuggerCommand`.
  ## Generate the c++ proc that `lldb` will call to initialize this plugin.
  result = newStmtList()
  let interpreter = ident"interpreter"
  var debuggerLldbInitProc = quote do:
    proc debuggerLldbInit(debugger: SBDebuggerObj): bool {.exportc.} =
      var `interpreter` = debugger.GetCommandInterpreter()
  for registration in debuggerCommandsToAdd.items:
    var name: string
    var execBody: NimNode
    name = strVal(registration[0][1])
    for assignment in registration:
      template field: untyped = assignment[0]
      template value: untyped = assignment[1]
      case field.repr:
      of "exec":
        execBody = value
      of "complete":
        let symbol = gensym(nskProc, "debuggerCommandComplete_" & name)
        result.add quote do:
          proc `symbol`() = discard

    let symbol = gensym(nskProc, "debuggerCommand_" & name)
    let nameObj = ident("debuggerCommandObj_" & name)
    let newId = ident("debuggerCommandNew_" & name)
    let exec = ident("debuggerCommandExec_" & name)
    let adapter = """
struct """ & $nameObj & """ : public SBCommandPluginInterface {
  virtual bool DoExecute(SBDebugger debugger, char** command, SBCommandReturnObject &result) {
    return """ & $exec & """(command);
  }
};
""" & $nameObj & """ * """ & $newId & """() { return new """ & $nameObj & """(); }"""
    result.add quote do:
      proc `exec`(command {.inject.}: ptr cstring): bool {.exportc.} = `execBody`
      {.emit: `adapter`.}
      type `nameObj` {.importcpp.} = object
      proc `newId`: ptr `nameObj` {.importcpp.}
    debuggerLldbInitProc[6].add quote("@") do:
      doAssert @interpreter.AddCommand(@name, cast[SBCommandPluginInterface](@newId()), "").IsValid()

  debuggerLldbInitProc[6].add(newLit(true))
  result.add(debuggerLldbInitProc)

  result.add quote do:
    {.emit: """
namespace lldb {
  bool PluginInitialize(SBDebugger debugger) { return debuggerLldbInit(debugger); }
}"""
    .}

template `+=`(p: ptr cstring, off: int) =
  p = cast[ptr cstring](cast[int](p) + (off * sizeof(ptr cstring)))

iterator args(command: ptr cstring): cstring =
  var args = command
  if args != nil:
    var arg = args[]
    while arg.len > 0:
      yield arg
      args += 1
      if args != nil:
        arg = args[]


macro addDebuggerCommand(body) =
  var registration = newTree(nnkPar)
  for stmt in body:
    expectKind stmt, nnkCall
    template field: untyped = stmt[0]
    template value: untyped = stmt[1][0]
    registration.add newTree(nnkExprColonExpr, field, value)
  debuggerCommandsToAdd.add registration

addDebuggerCommand:
  name: "repr"
  prefix: "nim"
  prefixHelp: "nim debug commands"
  help: "example"
  exec:
    for arg in command.args():
      echo arg
    return true

#[
addDebuggerCommand:
  name: "ee"
  shortHelp: "eexample"
  exec:
    for arg in command.args():
      echo arg
    return true ]#

genPluginEntryPoint()
