# Independent QA Records

This directory tracks QA state and exact evidence identities without committing large immutable evidence bundles.

For each gate record:

- candidate filename/build;
- candidate hashes;
- QA start/stop/elapsed;
- environment;
- findings;
- verdict;
- exact QA handoff SHA-256;
- next routing.

Never replace an existing QA record to make a later candidate look like the earlier one.
