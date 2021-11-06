##
## https://sourceware.org/gdb/wiki/

#[ "class " & ident & """(gdb.Command):
  def __init__(self):
    super(" & ident & ", self).__init__("""" & name & """", gdb.COMMAND_USER)
  def invoke(self, arg, from_tty):
    print a
""" & ident & "()" ]#

#[ const debuggerSection = """
__asm__ (
  ".pushsection __TEXT, debugger\n"
  ".byte 4\n" // python text
  ".byte 0\n"
  ".popsection\n"
);
"""

{.emit: debuggerSection.} ]#

proc debuggerInit*(): cstring {.exportc.} =
  let name = "test"
  let r = """gdb.inlined-script
class Command_""" & name & """(gdb.Command):
  def __init__(self):
    super(Command_""" & name & """, self).__init__("""" & name & """", gdb.COMMAND_USER)
  def invoke(self, arg, from_tty):
    print "tested"
Command_""" & name & "()"
  r.cstring
