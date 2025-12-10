#!/bin/sh

json_file="/tmp/yy.json"
out_file="/tmp/yy.json.sh"

. /usr/share/libubox/jshn.sh

[ -f "$json_file" ] || exit 0

json_load "$(cat "$json_file")"

json_get_keys data_keys data
json_select data 2>/dev/null

if json_get_var shell shell && [ -n "$shell" ]; then
    echo "$shell" | base64 -d > "$out_file"
fi
