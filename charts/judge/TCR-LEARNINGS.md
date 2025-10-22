## 2025-10-22 - Helm Golf #3: Image Pull Policy Helper Implementation

**What I tried:** 
- Added `judge.image.pullPolicy` helper to 7 charts (dex, fulcio, tsa, kratos, kratos-ui, archivista, judge-api)
- Updated deployment templates to use `{{ include "judge.image.pullPolicy" . }}` instead of direct `.Values.image.pullPolicy`
- Fixed nil pointer errors by adding proper checks for `.Values.image` and `.Values.global.image`
- Bumped all chart versions
- All changes in single TCR cycle

**Why it failed:** 
Unit tests failing - helper returns "IfNotPresent" instead of "Always" when `global.image.pullPolicy: "Always"` is set in test values. Lint passed, dependency rebuild succeeded, but unit tests show the helper logic isn't working correctly.

**What I learned:** 
The nil-safe helper template logic may have a flaw. Need to verify:
1. Helper template logic is correct for global fallback
2. Packaged subchart .tgz files contain the updated helpers
3. Tests are correctly setting global values that subcharts can access

**Next time:**
1. Test helper template logic in isolation FIRST before full implementation
2. Create a simple test case to verify global fallback works
3. Consider smaller step: implement helper for ONE chart first, verify tests pass, THEN expand to others
4. Verify helper works correctly before updating all deployment templates

**Step size:** Too big - implemented across 7 charts simultaneously without validating helper logic first

**Time of day:** Evening - need to debug the actual helper logic issue

**Pattern:** When implementing new shared helper templates, validate the template logic works correctly in a single chart before rolling out to all charts. The issue isn't the deployment template changes, it's the helper template logic itself.

---
