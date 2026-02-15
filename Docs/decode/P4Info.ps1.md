# Decode Analysis: P4Info.ps1

## Definition
**Path**: `P4Info.ps1`

### Parameters
- `[switch] $Config`: Output a `.p4config` compatible format.
- `[switch] $Full`: Run `p4 info` (full) instead of `p4 info -s` (short).

## Usages
No invocation usages found in other scripts (only self-reference in comments).

## Invocation Details
Used primarily to inspect P4 environment or generate `.p4config` files.

## Observations
- Checks `[PSVersionCheck.ps1](../../PSVersionCheck.ps1)`.
- Parses output of `p4 info` into a dictionary.
