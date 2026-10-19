# Linux adapter contract

The Linux adapter is intentionally not implemented in Version 1. Core modules
must consume only structured check results and may not import Windows-specific
modules directly. A future Linux adapter must return the same fields defined by
`core/Models.psm1`, preserve scan-only read semantics, and keep actions behind
the same explicit safety classifications.
