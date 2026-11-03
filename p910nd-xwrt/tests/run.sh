#!/bin/sh
# Usage: UCI=/path/to/native/uci tests/run.sh /path/to/patched/p910nd-source
set -eu
# shellcheck disable=SC2169
ulimit -c 0

source_dir=$(cd "${1:?Pass the patched p910nd source directory}" && pwd)
test_dir=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
test_build=$(mktemp -d)
trap 'rm -r "$test_build"' EXIT HUP INT TERM

"${CC:-cc}" -g -O1 -fsanitize=address,undefined -fno-omit-frame-pointer \
	-DP910ND_SOURCE="\"$source_dir/p910nd.c\"" \
	"$test_dir/test_forwarding.c" -o "$test_build/test_forwarding"
export ASAN_OPTIONS=detect_stack_use_after_return=1
for testcase in wrapped errors partial device busy closed-status large-job; do
	"$test_build/test_forwarding" "$testcase"
	printf 'PASS: %s\n' "$testcase"
done
python3 "$test_dir/test_scripts.py"
