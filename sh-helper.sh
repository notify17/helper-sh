#!/usr/bin/env sh

: "${AWK=awk}"
: "${WGET=wget}"

RAW_API_KEY=
TITLE=
CONTENT=

WGET_OPTS_DEFAULT="-q -O/dev/null"
WGET_OPTS="$WGET_OPTS_DEFAULT"
MAX_RETRIES_DEFAULT=5
MAX_RETRIES=$MAX_RETRIES_DEFAULT

print_usage() {
  echo "Usage: sh-helper.sh -k RAW_API_KEY -t TITLE [-c CONTENT]"
  echo ""
  echo "Find more docs at: https://notify17.net/recipes/n17-helper-bash/"
  echo ""
  echo "Options:"
  echo "-k/--key RAW_API_KEY  | Raw API key"
  echo "-t/--title TITLE      | Title of the notification (use - to capture stdin)"
  echo "-c/--content CONTENT  | Content of the notification (use - to capture stdin)"
  echo "-x/--trace            | Trace script execution"
  echo "-w/--wget-opts OPTS   | Set options to use with wget (default: $WGET_OPTS_DEFAULT)"
  echo "-r/--max-retries NUM  | Set the max number of retries (default: $MAX_RETRIES_DEFAULT)"
  echo "-h/--help             | Print this message"
}

# Parse all arguments
while test $# -gt 0; do
  case "$1" in
  -x | --trace)
    set -x
    ;;
  -k | --key)
    RAW_API_KEY="${2:-}"
    shift
    ;;
  -t | --title)
    TITLE="${2:-}"
    shift
    ;;
  -c | --content)
    CONTENT="${2:-}"
    shift
    ;;
  -w | --wget-opts)
    WGET_OPTS="${2:-}"
    shift
    ;;
  -r | --retries)
    MAX_RETRIES="${2:-}"
    shift
    ;;
  -h | --help)
    print_usage
    ;;
  esac
  shift
done

# Validate arguments

if [ -z "$RAW_API_KEY" ]; then
  echo "Missing raw API key"
  print_usage
  exit 1
fi

if [ -z "$TITLE" ]; then
  echo "Missing title"
  print_usage
  exit 1
fi

if ! [ "$MAX_RETRIES" -eq "$MAX_RETRIES" ] 2>/dev/null; then
  echo "Invalid max retries value, must be an integer."
  print_usage
  exit 1
fi

# Inspired by http://www.shelldorado.com/scripts/cmds/urlencode
awk_url_encode() {
  # shellcheck disable=SC2016
  echo "$1" | $AWK '
BEGIN {
EOL = "%0A"     # "end of line" string (encoded)
split ("1 2 3 4 5 6 7 8 9 A B C D E F", hextab, " ")
hextab [0] = 0
for ( i=1; i<=255; ++i ) ord [ sprintf ("%c", i) "" ] = i + 0
}
{
encoded = ""
for ( i=1; i<=length ($0); ++i ) {
  c = substr ($0, i, 1)
  if ( c ~ /[a-zA-Z0-9.-]/ ) {
    encoded = encoded c     # safe character
  } else if ( c == " " ) {
    encoded = encoded "+"   # special handling
  } else {
    # unsafe character, encode it as a two-digit hex-number
    lo = ord [c] % 16
    hi = int (ord [c] / 16);
    encoded = encoded "%" hextab [hi] hextab [lo]
  }
}
printf ("%s", encoded EOL)
}
END {
}
'
}

# Check if we need to use stdin
if [ "$TITLE" = "-" ] || [ "$CONTENT" = "-" ]; then
  STDIN=$(cat -)
  [ "$TITLE" = "-" ] && TITLE="$STDIN"
  [ "$CONTENT" = "-" ] && CONTENT="$STDIN"
fi

# Compose the request URL
URL="https://hook.notify17.net/api/raw/${RAW_API_KEY}"
QUERY=""

# Encode URL variables for the request
TITLE_ENC=$(awk_url_encode "$TITLE")
QUERY="$QUERY&title=$TITLE_ENC"

if [ -n "$CONTENT" ]; then
  CONTENT_ENC=$(awk_url_encode "$CONTENT")
  QUERY="$QUERY&content=$CONTENT_ENC"
fi

# Send the request and retry on error
n=0
until [ "$n" -gt "$MAX_RETRIES" ]; do
  FINAL_URL="${URL}?${QUERY}"

  # shellcheck disable=SC2086
  $WGET $WGET_OPTS "$FINAL_URL" && break
  n=$((n + 1))
  sleep 1
done

exit 0