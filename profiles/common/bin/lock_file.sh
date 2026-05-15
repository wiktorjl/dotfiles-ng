#!/bin/bash
#
# Encrypt or decrypt files using `age` with a passphrase.
#
# Usage:
#   lock_file.sh <file> [<file> ...]      # encrypt -> writes <file>.age, removes <file>
#   lock_file.sh -d <file.age> [...]      # decrypt -> writes <file>, KEEPS <file>.age
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

force=false
mode="encrypt"

# Parse leading flags. Order: -d (decrypt), -f (force overwrite), then files.
while [ $# -gt 0 ]; do
    case "$1" in
        -d) mode="decrypt"; shift ;;
        -f) force=true; shift ;;
        --) shift; break ;;
        -*) echo "Unknown flag: $1" >&2; exit 2 ;;
        *) break ;;
    esac
done

if [ $# -eq 0 ]; then
    echo "Usage: $0 [-d] [-f] <file> [<file> ...]" >&2
    exit 2
fi

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
        if age --decrypt -o "$plaintext" "$file"; then
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
        if age --passphrase -o "$ciphertext" "$file"; then
            echo "Encryption successful. Removing plaintext $file."
            rm -f "$file"
        else
            echo "Encryption failed for $file." >&2
            overall_exit_code=1
        fi
    done
fi

exit $overall_exit_code
