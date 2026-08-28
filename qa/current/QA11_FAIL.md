# QA11 — Independent QA FAIL

Build: `2026.08.27-eng-qa11`

Finding: **QA11-F-010 — cancelled Full Check can persist state that crashes the next UI relaunch**.

Active tracker: **Issue #1** in this standalone repository.

## Exact failed product

```text
Setup:       2E4CE0BFE42C2E88548D3C8C039F3B2C04A829940A1A6444F9F333A665D71C26
Portable:    810B93A242F539C86E657A192A88EDFB934402E5FBE24030F5CA5C1AB63EF07D
Source ZIP:  19AAE16749580CA8023711E081B1DCFDC0728CA5C6301DD55716E385CA775470
Source tree: C4273FA058A9151EF7E51EDE2EC264892CA707FF5957B7F5C39EA0DB7D599EAA
```

Independent QA11 FAIL Master Handoff SHA-256:

`E962569A552847A4FF9F6D08A165E4E1144B13ECB80A5D530AEE612BD0A4F820`

## Already-green native baseline

```text
Smoke                         107/107 PASS
Standard privilege/rollback   12/12 PASS
QA2 migration                244/244 PASS
Standard lifecycle            44/44 PASS
Elevated privilege/rollback   14/14 PASS
Elevated lifecycle            50/50 PASS
```

## Required correction

Validate/normalize persisted scan state before UI consumption. Cancelled/partial scan results must satisfy the supported result model or degrade safely without UI crash.

Carry F-001 through F-010 forward.

## Routing

Engineering works on `eng/f010-persisted-scan-validation` and returns a new immutable candidate to Independent QA.

The historical pre-cutover tracker `dietrichailabs-oss/Nyx#10` is no longer authoritative.
