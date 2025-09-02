
# hex_to_upper var hexstring
hex_to_upper() {
	local var_name=$1
	local value=$2

	value=${value//a/A}
	value=${value//b/B}
	value=${value//c/C}
	value=${value//d/D}
	value=${value//e/E}
	value=${value//f/F}

	export $var_name="$value"
}

# hex_to_lower var hexstring
hex_to_lower() {
	local var_name=$1
	local value=$2

	value=${value//A/a}
	value=${value//B/b}
	value=${value//C/c}
	value=${value//D/d}
	value=${value//E/e}
	value=${value//F/f}

	export $var_name="$value"
}

# readfile var file
readfile() {
	[[ -f "$2" ]] || return 1
	# read returns 1 on EOF
	read -d'\0' $1 <"$2" || :
}

# find_first_matching_line var pat txt
find_first_matching_line()
{
	local var_name=$1
	local pat=$2
	local txt="$3"
	local OIFS="$IFS"
	IFS=$'\n'
	for value in $txt; do
		if [[ "$value" = *"$pat"* ]]; then
			export $var_name="$value"
			break
		fi
	done
	IFS="$OIFS"
}
