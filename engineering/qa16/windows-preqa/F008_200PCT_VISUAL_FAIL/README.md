# QA16 frozen candidate: Engineering visual failure return
Engineering status: BLOCKED. Engineering -> Independent QA only.
No Independent QA PASS or release approval.

Corrected build: 195/195 Python checks PASS. Focused window containment passed
at 100%, 125%, 150%, and 200%. The 150%/1366x768 case was executed. These are
bounds checks, not full visual/accessibility passes.

The 200%/192 DPI, 1366x768, FollowWindows/Home real installed EXE screenshot
shows clipped branding/headings and truncated Export report, Check My PC,
Run Full Check and Cancel scan labels. Settings is below the visible navigation
viewport; keyboard reachability was not tested. Native and in-process bounds
remain within the working area. The full physical screenshot includes the taskbar.

The old one-pixel 125% result was an observer virtualization artifact, superseded
by corrected physical-pixel captures. Do not classify that old result as a defect.
Form.DeviceDpi reports 96 while graphics/native-window DPI reaches 192. This
is recorded, not asserted as the root cause. No product patch was attempted.

Full F008 matrix: 0 PASS / 1 FAIL / 131 NOT_RUN. Focused bounds successes do not
count as full UI cell passes. Standard, Elevated, F-010, F-011 and F-012 successor
campaigns are NOT RUN. Candidate bytes stay frozen; prior QA15 remains untouched.
Independent QA decides disposition and any successor correction.
