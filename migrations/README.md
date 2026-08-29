# OMacOS migrations

Versioned, idempotent user-state migrations live here as executable `*.zsh` files. The migration runner records each filename only after it exits successfully, so interrupted upgrades safely resume at the failed migration.
