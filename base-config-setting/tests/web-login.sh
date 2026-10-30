#!/bin/sh
# Run on OpenWrt. All UCI operations use private config and delta directories.
set -eu

test_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
uci_bin=$(command -v uci)
work=$(mktemp -d /tmp/xwrt-web-login.XXXXXX)
trap 'rm -rf "$work"' EXIT INT TERM
mkdir -p "$work/delta" "$work/overrides"

uci() {
	case "${fail_operation:-}:$*" in
		commit:*'commit rpcd'|delete:*'delete rpcd.root_first') return 1 ;;
	esac
	"$uci_bin" -c "$work" -C "$work/overrides" -t "$work/delta" "$@"
}

sed -n '/# BEGIN configured-web-login migration$/,/# END configured-web-login migration$/p' \
	"$test_dir/../files/uci.defaults" | sed 's/config_luci_login=%LUCI_LOGIN%/config_luci_login=$build_login/' > "$work/migration.sh"

fixture() {
	"$uci_bin" -c "$work" -C "$work/overrides" -t "$work/delta" revert rpcd 2>/dev/null || true
	cat > "$work/rpcd" <<'EOF'
config login 'root_first'
	option username 'root'
	option password '$p$root'
config login
	option username 'root'
config login 'configured'
	option username 'operator'
	option password 'password-kept'
	list read '*'
	list write '*'
EOF
}

run_migration() {
	# Production uci.defaults does not use errexit; exercise failures likewise.
	set +e
	. "$work/migration.sh"
	continued=1
	set -e
}

fixture
build_login=admin
run_migration
[ "$(uci -q show rpcd | sed -n '/=login$/p' | wc -l)" -eq 1 ]
[ "$(uci get rpcd.configured.username)" = operator ]
[ "$(uci get rpcd.configured.password)" = password-kept ]
[ "$(uci get rpcd.configured.write)" = '*' ]
echo 'PASS non-root build removes root entries without forcing admin or changing credentials'

before=$(sha256sum "$work/rpcd")
run_migration
[ "$(sha256sum "$work/rpcd")" = "$before" ]
echo 'PASS migration is idempotent'

fixture
build_login=root
before=$(sha256sum "$work/rpcd")
run_migration
[ "$(sha256sum "$work/rpcd")" = "$before" ]
echo 'PASS root build keeps root web login and all existing settings'

build_login=''
run_migration
[ "$(sha256sum "$work/rpcd")" = "$before" ]
echo 'PASS empty build setting leaves logins unchanged'

build_login=operator
fail_operation=delete
continued=0
run_migration
[ "$continued" = 1 ]
[ "$(uci get rpcd.root_first.username)" = root ]
[ "$(uci -q show rpcd | sed -n '/=login$/p' | wc -l)" -eq 2 ]
[ "$(uci get rpcd.configured.password)" = password-kept ]
echo 'PASS failed deletion does not stop later entries or initialization'

fixture
before=$(sha256sum "$work/rpcd")
fail_operation=commit
continued=0
run_migration
[ "$continued" = 1 ]
[ "$(sha256sum "$work/rpcd")" = "$before" ]
echo 'PASS failed commit does not stop initialization'
