#!/bin/sh
# NOTE: WIP
# See Also: https://sourceware.org/gdb/wiki/PermissionsDarwin#Sign_and_entitle_the_gdb_binary

macos_pre_10_14() {
	:
}

macos_post_10_14() {
	:
}

macos_version() {
	# Source: https://coderwall.com/p/4yz8dq/determine-os-x-version-from-the-command-line
	v=$(defaults read loginwindow SystemVersionStampAsString)
	major=${v%%.*}
	minor=${v#*.}
	minor=${minor%.*}
	patch=${v##*.}
	if [ ${minor} -ge 14 ]
	then macos_post_10_14
	else macos_pre_10_14
	fi
}

macos_version
