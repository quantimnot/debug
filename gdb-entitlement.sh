#!/bin/sh
# NOTE: WIP
# See Also: https://sourceware.org/gdb/wiki/PermissionsDarwin#Sign_and_entitle_the_gdb_binary

# TODO: What are the risks of leaving an "entitled" program that can launch other programs exposed on the fs?

macos_create_gdb_cert() {
	sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain <der_encoded_x509_cert>
}

macos_pre_10_14() {
	codesign -fs gdb "$(command -v gdb)"
}

macos_10_14_plus() {
	codesign --entitlements gdb-entitlement.xml -fs gdb "$(command -v gdb)"
}

macos_version() {
	# Source: https://coderwall.com/p/4yz8dq/determine-os-x-version-from-the-command-line
	v=$(defaults read loginwindow SystemVersionStampAsString)
	major=${v%%.*}
	minor=${v#*.}
	minor=${minor%.*}
	patch=${v##*.}
	if [ ${minor} -ge 14 ]
	then macos_10_14_plus
	else macos_pre_10_14
	fi
}

macos_version
