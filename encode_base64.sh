#!/usr/bin/env bash
# =============================================================================
# encode_base64.sh
# -----------------------------------------------------------------------------
# PURPOSE
#   Reads a text file of plaintext passwords (one per line) and writes a new
#   file containing the Base64-encoded version of each line (one per line).
#
# USAGE
#   chmod +x encode_base64.sh
#   ./encode_base64.sh
#   (The script then prompts for the input file and the output file.)
#
#   Example session:
#     Enter path to input file (plaintext passwords): passwords.txt
#     Enter path to output file (Base64 output): encoded.txt
#
# BEHAVIOUR
#   - Empty lines in the input are skipped; order of other lines is preserved.
#   - Windows line endings (CRLF) are tolerated (the trailing \r is removed).
#   - Works on GNU/Linux and macOS using the `base64` utility; if that is not
#     available it falls back to Python 3.
#   - Exits with a non-zero status on any fatal error:
#       1 = bad input/output file problem   2 = no Base64 encoder available
#       3 = user aborted                    4 = encoding failure
#
# NOTE
#   Base64 is an ENCODING, not encryption. Anyone can decode it.
# =============================================================================

set -u                                   # treat unset variables as errors

# ---- helper: print an error message to stderr and exit ----------------------
die() {                                  # usage: die <exit_code> <message>
    echo "ERROR: $2" >&2
    exit "$1"
}

# ---- choose a Base64 encoding method (done once, up front) ------------------
# ENCODER is set to "base64" or "python3".
if command -v base64 >/dev/null 2>&1; then
    ENCODER="base64"
elif command -v python3 >/dev/null 2>&1; then
    ENCODER="python3"
else
    die 2 "Neither 'base64' nor 'python3' was found. Install one and retry."
fi

# ---- encode one string; result printed on a single line, no newline wrap ----
encode_line() {                          # usage: encode_line "<plaintext>"
    if [ "$ENCODER" = "base64" ]; then
        # printf '%s' avoids adding a trailing newline to the data.
        # GNU base64 wraps at 76 chars; macOS doesn't. `tr -d` removes any
        # wrapping newlines so the output is always exactly one line.
        printf '%s' "$1" | base64 | tr -d '\r\n'
    else
        python3 -c 'import sys,base64; sys.stdout.write(base64.b64encode(sys.argv[1].encode("utf-8")).decode("ascii"))' "$1"
    fi
}

# ---- prompt for file names ---------------------------------------------------
read -r -p "Enter path to input file (plaintext passwords): " IN_FILE
read -r -p "Enter path to output file (Base64 output): " OUT_FILE

# ---- validate input file ------------------------------------------------------
[ -n "$IN_FILE" ]  || die 1 "No input file given."
[ -n "$OUT_FILE" ] || die 1 "No output file given."
[ -e "$IN_FILE" ]  || die 1 "Input file '$IN_FILE' does not exist."
[ -f "$IN_FILE" ]  || die 1 "'$IN_FILE' is not a regular file."
[ -r "$IN_FILE" ]  || die 1 "Input file '$IN_FILE' is not readable."
[ "$IN_FILE" != "$OUT_FILE" ] || die 1 "Input and output must be different files."

# ---- validate output location -------------------------------------------------
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

# ---- main loop ----------------------------------------------------------------
: > "$OUT_FILE" || die 1 "Cannot write to '$OUT_FILE'."

COUNT=0      # lines encoded
SKIPPED=0    # empty lines skipped

# `|| [ -n "$line" ]` makes sure a last line without a trailing newline is read.
# IFS= and -r preserve leading/trailing spaces and backslashes in passwords.
while IFS= read -r line || [ -n "$line" ]; do
    line=${line%$'\r'}                   # strip CR from Windows-style files

    if [ -z "$line" ]; then              # skip empty lines
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    encoded=$(encode_line "$line") || die 4 "Encoding failed for a line (method: $ENCODER)."
    printf '%s\n' "$encoded" >> "$OUT_FILE" || die 1 "Failed writing to '$OUT_FILE'."
    COUNT=$((COUNT + 1))
done < "$IN_FILE"

# ---- summary -------------------------------------------------------------------
echo "Done. Method: $ENCODER | Encoded: $COUNT | Empty lines skipped: $SKIPPED"
echo "Output written to: $OUT_FILE"
exit 0
