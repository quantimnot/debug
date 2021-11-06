default: lldb.log gdb.log

lldb.log: debuggee lldbinit
	lldb --batch --no-lldbinit --source lldbinit debuggee

gdb.log: debuggee gdbinit
	gdb -nx -x gdbinit debuggee

debuggerutils.so: debuggerutils.nim
	nim cpp --debugger:native --app:lib -o:$@ debuggerutils.nim

debugger.so: ../../debugger.nim
	nim c --threads:on --debugger:native --app:lib -o:$@ ../../debugger.nim

debuggee: debuggerutils.so debugger.so debuggee.nim
	nim c --nimcache:nimcache --debugger:native -l:"./debugger.so" -l:"./debuggerutils.so" debuggee.nim
