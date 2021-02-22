#******
#* SEE ALSO
#******

when defined(debug):
  {.warning: "DEBUG MODE".}
  switch("debugger", "native")
  switch("verbosity", "1")
  switch("passC", "-g")
  switch("passL", "-g")
  switch("define", "sanitize")
  switch("define", "runtime_checks")

when defined(runtime_checks):
  switch("obj_checks", "on")
  switch("field_checks", "on")
  switch("bound_checks", "on")

