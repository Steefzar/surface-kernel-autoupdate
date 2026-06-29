function yay --wraps yay --description 'yay + surface kernel auto-build into local repo'
    # On a full system upgrade, build any newer Surface kernel into the local repo
    # FIRST, so yay's db refresh + upgrade picks it up in the same transaction.
    set -l joined (string join ' ' -- $argv)
    if test (count $argv) -eq 0; or string match -qr -- '-S[a-z]*u' "$joined"
        ~/.local/bin/surface-kernel-update
    end

    command yay $argv
end
