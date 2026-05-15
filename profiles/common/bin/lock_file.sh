#!/bin/bash
#
# Encrypt or decrypt files using `age` with a passphrase.
#
# Usage:
#   lock_file.sh [-f] <file> [<file> ...]      # encrypt -> writes <file>.age, removes <file>
#   lock_file.sh -d [-f] <file.age> [...]      # decrypt -> writes <file>, KEEPS <file>.age
#   lock_file.sh -h | --help                   # show usage and exit
#
# Flags:
#   -d           Decrypt mode (default is encrypt).
#   -f           Force overwrite of an existing output file.
#   -h, --help   Print this help and exit.
#
# Non-interactive use:
#   Set the LOCK_FILE_PASSPHRASE env var to drive `age --passphrase` without a
#   controlling terminal. Requires `script` (util-linux) on PATH.
#
#       LOCK_FILE_PASSPHRASE='hunter2' lock_file.sh secrets.txt
#
#   The passphrase appears in this process's environment; anyone able to read
#   /proc/<pid>/environ can see it. Use only on hosts you trust.
#
# Notes on safety:
#   * Decrypt does NOT remove the ciphertext. The previous version did, with
#     `rm -if`, which in non-interactive contexts silently kept the ciphertext
#     anyway *and* (when stdin was a tty) prompted the user — neither
#     behaviour is what you want for a one-shot crypto helper. If you want to
#     destroy the ciphertext, do it explicitly.
#   * Decrypt sets umask 077 so plaintext lands at mode 0600, not 0644.
#   * Decrypt refuses to overwrite an existing plaintext target unless the
#     caller passes `-f`.
#   * Encrypt continues to remove the plaintext on success (that is the whole
#     point of running it).

set -uo pipefail

usage() {
    sed -n '3,22p' "$0" | sed 's/^# \{0,1\}//'
}

force=false
mode="encrypt"

# Parse leading flags. Order: -d (decrypt), -f (force overwrite), -h/--help, then files.
while [ $# -gt 0 ]; do
    case "$1" in
        -d) mode="decrypt"; shift ;;
        -f) force=true; shift ;;
        -h|--help) usage; exit 0 ;;
        --) shift; break ;;
        -*) echo "Unknown flag: $1" >&2; usage >&2; exit 2 ;;
        *) break ;;
    esac
done

if [ $# -eq 0 ]; then
    usage >&2
    exit 2
fi

# Drive `age --passphrase` non-interactively when LOCK_FILE_PASSPHRASE is set.
# `age` reads the passphrase from /dev/tty, not stdin, so we allocate a PTY
# via script(1) and write the passphrase into it. Encrypt prompts twice for
# confirmation; sending it twice is harmless on decrypt (age reads only what
# it needs and ignores trailing input).
run_age() {
    if [ -z "${LOCK_FILE_PASSPHRASE-}" ]; then
        age "$@"
        return $?
    fi
    if ! command -v script >/dev/null 2>&1; then
        echo "Error: LOCK_FILE_PASSPHRASE is set but 'script' (util-linux) is not installed." >&2
        return 1
    fi
    local cmd
    cmd=$(printf '%q ' age "$@")
    printf '%s\n%s\n' "$LOCK_FILE_PASSPHRASE" "$LOCK_FILE_PASSPHRASE" \
        | script -qefc "$cmd" /dev/null >/dev/null
}

overall_exit_code=0

if [ "$mode" = "decrypt" ]; then
    umask 077
    for file in "$@"; do
        case "$file" in
            *.age) ;;
            *) echo "Refusing to decrypt $file: name does not end in .age" >&2
               overall_exit_code=1; continue ;;
        esac
        plaintext="${file%.age}"
        if [ -e "$plaintext" ] && [ "$force" != true ]; then
            echo "Refusing to overwrite existing $plaintext (pass -f to override)" >&2
            overall_exit_code=1
            continue
        fi
        echo "Decrypting $file -> $plaintext"
        if run_age --decrypt -o "$plaintext" "$file"; then
            echo "Decryption successful. Ciphertext $file kept on disk."
        else
            echo "Decryption failed for $file." >&2
            overall_exit_code=1
        fi
    done
else
    for file in "$@"; do
        if [ ! -f "$file" ]; then
            echo "Skipping $file: not a regular file" >&2
            overall_exit_code=1
            continue
        fi
        ciphertext="${file}.age"
        if [ -e "$ciphertext" ] && [ "$force" != true ]; then
            echo "Refusing to overwrite existing $ciphertext (pass -f to override)" >&2
            overall_exit_code=1
            continue
        fi
        echo "Encrypting $file -> $ciphertext"
        if run_age --passphrase -o "$ciphertext" "$file"; then
            echo "Encryption successful. Removing plaintext $file."
            rm -f "$file"
        else
            echo "Encryption failed for $file." >&2
            overall_exit_code=1
        fi
    done
fi

exit $overall_exit_code
