#****h* debug/debug
## PURPOSE
##   Set of debugging utilities.
## DESCRIPTION
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
  nimgdb
