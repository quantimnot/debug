#****h* debug/debug
## PURPOSE
##   Set of debugging utilities.
## FEATURES
##   - [ ] MI parser
##   - [ ] MI translation/filtering
##   - [ ] GDB controller
##   - [X] logging
##   - [ ] software defined markers
##     - [ ] breakpoints
##     - [ ] tracepoints
##     - [ ] watchpoints
##   - [X] debug logging markers/logging are scoped by tags
##   - [ ] DAP server
##   - [ ] LLDB controller
##   - [ ] windbg controller
#******
import
  debug_tags,
  debug_logging,
  debug_markers,
  debug_mi,
  debug_dap,
  nimgdb
