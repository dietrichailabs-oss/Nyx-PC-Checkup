# QA15 F-012 settings theme-save correction

Build: `2026.09.01-eng-qa15`
Harness: `QA15-F012-PS51-15`

F-012 replaces deferred function-local Settings control references with an explicit state object owned by the Save button. The handler validates FollowWindows, Dark, or Light; persists theme, notifications, and update settings; and displays success only after configuration save returns.

QA14 remains frozen on `eng/f011-installed-launch-visible-window`.
