load_secret() {
  local var_name="$1"
  local file_value="$2"
  local direct_value="$3"

  if [[ -n "$file_value" ]]; then
    export "$var_name"="$(cat $file_value)"
  else
    export "$var_name"="$direct_value"
  fi
}
