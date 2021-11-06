def __lldb_init_module(debugger, internal_dict):
  target = debugger.GetTargetAtIndex(0)
  debuggerInit = target.FindGlobalFunctions("debuggerInit", 1, lldb.eMatchTypeStartsWith)
  if len(debuggerInit) > 0:
    print("Initializing Nim debug runtime...")
    options = lldb.SBExpressionOptions()
    process = target.GetProcess()
    thread = process.selected_thread
    frame = thread.GetSelectedFrame()
    debuggerInit = debuggerInit[0].GetFunction()
    print debuggerInit.GetName()
    result = frame.EvaluateExpression("", options)
    print result
    #(debuggerInit.GetFunction().GetSymbol().GetStartAddress().GetLoadAddress(lldb.target))()