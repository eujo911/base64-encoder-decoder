#!/usr/bin/env bash
# =============================================================================
# decode_base64.sh   (bonus)
# -----------------------------------------------------------------------------
# PURPOSE
#   Reads a file of Base64 strings (one per line) and writes the decoded
#   plaintext (one line per entry) to an output file.
#
# USAGE
#   chmod +x decode_base64.sh
#   ./decode_base64.sh
#   (The script then prompts for the input file and the output file.)
#
#   Example session:
#     Enter path to input file (Base64 strings): encoded.txt
#     Enter path to output file (decoded plaintext): decoded.txt
#
# BEHAVIOUR
#   - Detects which decode flag the system's `base64` supports
#     (--decode on GNU, -d on newer macOS/BSD, -D on older macOS).
#   - Falls back to Python 3 if no working `base64` is found.
#   - Empty lines are skipped.
#   - An invalid Base64 line does NOT stop the script: a placeholder line
#     "[DECODE ERROR: invalid Base64 -> <original text>]" is written and
#     processing continues, so output line N always matches input entry N.
#   - Exit codes: 1 = file problem, 2 = no decoder available, 3 = user aborted.
# =============================================================================

set -u

die() {                                  # usage: die <exit_code> <message>
    echo "ERROR: $2" >&2
    exit "$1"
}

# ---- detect the decode method (done once, up front) ---------------------------
# DECODER = "base64" (with DECODE_FLAG set) or "python3".
DECODER=""
DECODE_FLAG=""

if command -v base64 >/dev/null 2>&1; then
    # Try each flag against a known string: "YQ==" must decode to "a".
    for flag in --decode -d -D; do
        if [ "$(printf 'YQ==' | base64 "$flag" 2>/dev/null)" = "a" ]; then
            DECODER="base64"
            DECODE_FLAG="$flag"
            break
        fi
    done
fi

if [ -z "$DECODER" ]; then
    if command -v python3 >/dev/null 2>&1; then
        DECODER="python3"
    else
        die 2 "No working 'base64' flag (--decode, -d, -D) and no python3 found."
    fi
fi

# ---- is the string syntactically valid Base64? ---------------------------------
# Some base64 tools (notably macOS) silently accept garbage, so we check
# ourselves: only A-Z a-z 0-9 + / with up to two '=' padding chars, and the
# length must be a multiple of 4.
is_valid_b64() {
    case "$1" in
        *[!A-Za-z0-9+/=]*) return 1 ;;
    esac
    [[ "$1" =~ ^[A-Za-z0-9+/]*={0,2}$ ]] || return 1
    [ $(( ${#1} % 4 )) -eq 0 ] || return 1
    return 0
}

# ---- decode one string; non-zero return on failure -------------------------------
decode_line() {
    if [ "$DECODER" = "base64" ]; then
        printf '%s' "$1" | base64 "$DECODE_FLAG" 2>/dev/null
    else
        python3 -c 'import sys,base64; sys.stdout.write(base64.b64decode(sys.argv[1], validate=True).decode("utf-8"))' "$1" 2>/dev/null
    fi
}

# ---- prompt for file names ---------------------------------------------------------
read -r -p "Enter path to input file (Base64 strings): " IN_FILE
read -r -p "Enter path to output file (decoded plaintext): " OUT_FILE

[ -n "$IN_FILE" ]  || die 1 "No input file given."
[ -n "$OUT_FILE" ] || die 1 "No output file given."
[ -e "$IN_FILE" ]  || die 1 "Input file '$IN_FILE' does not exist."
[ -f "$IN_FILE" ]  || die 1 "'$IN_FILE' is not a regular file."
[ -r "$IN_FILE" ]  || die 1 "Input file '$IN_FILE' is not readable."
[ "$IN_FILE" != "$OUT_FILE" ] || die 1 "Input and output must be different files."

OUT_DIR=$(dirname -- "$OUT_FILE")
[ -d "$OUT_DIR" ] || die 1 "Output directory '$OUT_DIR' does not exist."
[ -w "$OUT_DIR" ] || die 1 "Output directory '$OUT_DIR' is not writable."

if [ -e "$OUT_FILE" ]; then
    read -r -p "'$OUT_FILE' already exists. Overwrite? [y/N]: " ANSWER
    case "$ANSWER" in
        y|Y|yes|YES) ;;
        *) die 3 "Aborted by user; nothing was written." ;;
    esac
fi

: > "$OUT_FILE" || die 1 "Cannot write to '$OUT_FILE'."

OK=0; BAD=0; SKIPPED=0

while IFS= read -r line || [ -n "$line" ]; do
    line=${line%$'\r'}                   # tolerate CRLF files

    if [ -z "$line" ]; then
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    if is_valid_b64 "$line" && decoded=$(decode_line "$line"); then
        printf '%s\n' "$decoded" >> "$OUT_FILE" || die 1 "Failed writing to '$OUT_FILE'."
        OK=$((OK + 1))
    else
        # Graceful handling: write a placeholder and keep going.
        printf '%s\n' "[DECODE ERROR: invalid Base64 -> $line]" >> "$OUT_FILE" \
            || die 1 "Failed writing to '$OUT_FILE'."
        BAD=$((BAD + 1))
    fi
done < "$IN_FILE"

echo "Done. Method: $DECODER ${DECODE_FLAG} | Decoded: $OK | Errors: $BAD | Empty skipped: $SKIPPED"
echo "Output written to: $OUT_FILE"
exit 0
