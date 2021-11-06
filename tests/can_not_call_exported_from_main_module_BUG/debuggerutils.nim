import "../.."/lldb

proc getInt*(): cint {.exportc.} =
  1
proc getCString*(): cstring {.exportc.} =
  "a"
