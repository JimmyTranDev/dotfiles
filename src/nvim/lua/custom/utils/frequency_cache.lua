-- Backward-compatible alias. Superseded by `usage_cache`, which stores
-- `{ count, last_used }` per key and adds recency ordering. Kept as a shim so
-- any lingering caller of `frequency_cache` keeps working.
return require('custom.utils.usage_cache')
