# TCR Learning Log

Document TCR failures to build pattern recognition and calibrate step sizes.

---

## 2025-10-30 10:52 - Global values not accessible in subchart helper templates

**What I tried:**
- Added `global.secrets.manual` configuration structure to parent chart's values.yaml with secretName/secretKey overrides for judgeApi, archivista, and kratos
- Updated judge-api helper templates (`_helpers.tpl`) to check for global manual overrides using `hasKey` checks with nested if statements
- Attempted multiple approaches: `and` with nil checks, `with` statements, and `hasKey` functions
- Removed global defaults from subchart values.yaml thinking they might override parent values

**Why it failed:**
- Helm unittest tests consistently failed - custom secret names and keys were never picked up
- Template rendering (via `helm template`) with explicit values file showed default names even when manual overrides were set
- The helper templates always fell back to default naming patterns (e.g., `RELEASE-NAME-judge-api-database`)
- Global values appeared to not be accessible from subchart helper templates despite multiple syntax attempts
- Test output: Expected `my-custom-db-secret`, got `RELEASE-NAME-judge-api-database`

**What I learned:**
1. **Values passing**: Global values from parent charts to subchart helper templates may require explicit declaration or different access patterns than I tried
2. **Test first**: Should have verified basic global value access works BEFORE implementing all the logic
3. **Pattern matching**: Should have examined how existing global values work (like `global.aws.accountId` in IRSA tests) before inventing new patterns
4. **Debugging limit**: Spent ~15 attempts debugging instead of reverting earlier per TCR discipline
5. **Step decomposition**: Tried to do too much at once (values structure + helper logic + multiple services)

**Next time:**
1. Start with minimal viable test: just try to echo `.Values.global.secrets.manual.judgeApi.secretName` in a simple template before adding logic
2. Study existing working examples of global values in this codebase first (grep for `.Values.global` usage)
3. Use `helm template --debug` early to verify values are actually being passed to subcharts
4. Consider if Helm has specific requirements for global values in subcharts (Chart.yaml dependencies?)
5. Test one service (judge-api) completely before adding archivista and kratos
6. Revert after 3-4 failed attempts rather than continuing to debug
7. Check Helm documentation on global values and subchart value passing

**Root cause hypothesis:**
- Helm subcharts may require explicit global value definitions in subchart's values.yaml (but I removed them)
- OR global values need to be accessed differently in template helpers vs templates
- OR helm unittest has different behavior than helm template for global values
- Need to investigate: How do other parts of this chart access global values from subcharts?

**Step size:** Too big
- Combined: values structure design + helper template logic + multiple conditional branches + two helper functions
- Should have been: Add values structure → Verify basic access works → Add one helper → Test → Add second helper → Test

**Time of day:** Mid-morning (10:52 AM) - should be peak clarity, suggests problem is conceptual not fatigue

**Pattern recognition:** This is my first attempt at global values in Helm subcharts - need to build baseline understanding before attempting complex logic.

**Confidence level before:** 60% - wasn't sure about global values mechanism but proceeded anyway
**Confidence level after:** 20% - need to study the mechanism more

**Research needed:**
- Helm documentation: global values in subcharts
- This codebase: grep for `.Values.global` to see working examples
- Helm unittest: how it handles global values vs regular helm template

---

## 2025-10-30 11:15 - Second attempt with simplified approach still failing

**What I tried:**
- Added `global.secrets.manual` structure to parent chart values.yaml (simpler than before)
- Updated ONLY the secretName helper in judge-api with pattern matching existing working code
- Used `hasKey` checks exactly like existing code: `if and .Values.global (hasKey .Values.global "secrets") (hasKey .Values.global.secrets "manual")...`
- Added explicit empty string check: `(ne .Values.global.secrets.manual.judgeApi.secretName "")`
- Tested with both `--set` flag and values file (`-f /tmp/test-values.yaml`)

**Why it failed:**
- Helm template rendering continues to show default name (`test-judge-api-database`) instead of custom name (`my-custom-db-secret`)
- Helm unittest shows same failure
- The global values appear to not be accessible even though pattern matches working code
- Both `helm template` and `helm unittest` show same behavior

**What I learned:**
1. **Copying patterns isn't enough**: Even using the exact same pattern as working code doesn't guarantee success
2. **Unknown unknowns**: There's something fundamental about how global values flow that I'm missing
3. **Debug capability needed**: Need a way to inspect what values are actually available at template render time
4. **Hypothesis invalidated**: My assumption that the syntax was wrong was incorrect - same syntax as working code still fails

**Next time:**
1. **Start from working code**: Instead of modifying helpers, find a working global value access and modify THAT
2. **Copy-modify-test**: Take an existing working template (like external-secret-database.yaml), add my manual override check to it, test THAT first
3. **Instrument before implement**: Add simple value echo before adding logic
4. **Consider Helm version**: Check if there are Helm version differences in behavior
5. **Ask for help**: This might be a case where I need expert input on Helm subchart value passing

**Root cause still unknown - possible reasons:**
1. Values file structure in parent chart needs something I'm missing (export? global keyword placement?)
2. Subchart needs explicit import of global values?
3. Helm unittest has different global value handling than helm template?
4. The parent chart's values.yaml structure has some issue with my manual section?
5. Dependencies vs subcharts might handle global values differently?

**Step size:** Already minimal - just values + one helper function with simple logic

**Time of day:** Late morning (11:15 AM) - still should be good focus

**Fatigue level:** Increasing frustration - need to stop and seek help or research more fundamentally

**Decision**: STOP and research Helm documentation on global values in dependent charts before attempting again. Current approach is clearly missing something fundamental.

**Action items:**
1. Read Helm official docs on global values
2. Find a minimal reproducible example of global values in subcharts
3. Test that minimal example in THIS chart
4. Only after verification, attempt to add manual override logic

**Confidence before this attempt:** 40% - thought simpler approach would work
**Confidence after:** 10% - fundamentally don't understand the mechanism

---
