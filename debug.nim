#****h* debug/debug
## PURPOSE
##   Set of debugging utilities.
## FEATURES
##   - [ ] MI translation/filtering
##   - [ ] GDB controller
##   - [ ] LLDB controller
##   - [ ] windbg controller
##   - [ ] software defined markers
##     - [ ] breakpoints
##     - [ ] tracepoints
##     - [ ] watchpoints
##     - [ ] logpoints
##   - [ ] DAP server
##   - [X] MI parser, *first working* version
##   - [X] debug logging markers/logging are scoped by tags
##   - [X] logging
#******
import
  debug_tags,
  debug_logging,
  debug_markers,
  debug_mi,
  debug_dap,
  nimgdb
