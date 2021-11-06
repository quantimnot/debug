#!/bin/sh -ue
#****h* debug/tui_session
#* PURPOSE
#*   Coordinate GDB and LLDB with tmux.
#*   Persist debug session to disk for later replay or review.
#* SEE ALSO
#*   - man tmux
#*   - man gdb
#*   - man valgrind
#* TODO
#*   - convert this to a Nim program
#******

number_of_debug_sessions_to_keep=1

use_single_session() {
	false
}

debug_session() {
	if use_single_session
	then echo .
	else date "+%Y%m%d%H%m%S%Z"
	#else date -j -f "%a %b %d %T %Z %Y" "$(date)" "+%s"
	fi
}

current_session=$(debug_session)
dbg=.debug/${current_session}

mkdir -p ${dbg}
(
cd .debug
rm -rf last
if [ -h current ]
then mv -f current last
else ln -sF current last
fi
ln -sF ${current_session} current
if [ -e last/gdb.history ]
then cp -f last/gdb.history current/gdb.history
fi
IFS='
'
for session in $(ls | head -n $(($(ls | sort | wc -l) - $((${number_of_debug_sessions_to_keep}+3)))))
do rm -rf "${session}"
done
)

invocation="${@:-}"
echo "${invocation}" > ${dbg}/invocation

cat > ${dbg}/gdbinit <<EOF
set logging file ${dbg}/gdb.log
set logging overwrite on
set logging on
set history filename ${dbg}/gdb.history
set history save on
set disassembly-flavor intel
set tui compact-source
set tui tab-width 2
EOF

gdbserver="gdbserver"
lldb_gdbserver="lldb-server gdbserver localhost:1500 --"
valgrind_gdbserver="valgrind \
--vgdb=full \
--vgdb-stop-at=all \
--track-origins=yes \
--leak-check=full \
--show-reachable=yes \
--show-leak-kinds=all \
--errors-for-leak-kinds=all \
--suppressions=debug/suppressions.valgrind \
--log-file=${dbg}/valgrind.log"

#tmux new -s debug_moe -d "${lldb_gdbserver} ${invocation} 2> ${moe_stderr_log_path}"
tmux new -d "${lldb_gdbserver} ${invocation} 2> ${dbg}/stderr.log | tee ${dbg}/stdout.log"

#tmux splitw -h -p 50 -t debug_moe "gdb -tui -x ${gdbinit_path} ${invocation}"
tmux splitw -h -p 50 "gdb -tui -x ${dbg}/gdbinit ${invocation}"
# Split the tmux window and create a new gdb client session.

#tmux attach -t debug_moe
# Attach to the debug session.

# gdb --tui -f ${dbg}/gdbinit --tty ${debuggee_tty}

