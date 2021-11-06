//#include "symcat.h"
//#include "gdb/section-scripts.h"

/*
// ELF
asm(
".pushsection \".debug_gdb_scripts\", \"MS\",@progbits,1\n"
".byte 4\n"
".ascii \"gdb.inlined-script\\n\"\n"
".ascii \"class test_cmd (gdb.Command):\\n\"\n"
".ascii \"  def __init__ (self):\\n\"\n"
".ascii \"    super (test_cmd, self).__init__ ("
    "\\\"test-cmd\\\", gdb.COMMAND_OBSCURE)\\n\"\n"
".ascii \"  def invoke (self, arg, from_tty):\\n\"\n"
".ascii \"    print (\\\"test-cmd output, arg = %s\\\" % arg)\\n\"\n"
".ascii \"test_cmd ()\\n\"\n"
".byte 0\n"
".popsection\n"
);
*/
asm(
".pushsection \".gdb_scripts\", \"MS\",1\n"
".byte 4\n"
".ascii \"gdb.inlined-script\\n\"\n"
".ascii \"class test_cmd (gdb.Command):\\n\"\n"
".ascii \"  def __init__ (self):\\n\"\n"
".ascii \"    super (test_cmd, self).__init__ ("
    "\\\"test-cmd\\\", gdb.COMMAND_OBSCURE)\\n\"\n"
".ascii \"  def invoke (self, arg, from_tty):\\n\"\n"
".ascii \"    print (\\\"test-cmd output, arg = %s\\\" % arg)\\n\"\n"
".ascii \"test_cmd ()\\n\"\n"
".byte 0\n"
".popsection\n"
);