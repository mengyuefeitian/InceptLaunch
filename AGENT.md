# Project Rules

## Post-Development: Version Bump & Build

After completing any feature, bugfix, or change set, ALWAYS perform the following steps before reporting the task as done:

1. **Bump version** in `script/build_and_run.sh`:
   - Increment the patch version (e.g. `1.6.0` → `1.6.1`) for bugfixes/small changes.
   - Increment the minor version (e.g. `1.6.0` → `1.7.0`) for new features.
   - Update BOTH `CFBundleShortVersionString` and `CFBundleVersion` (they must match).

2. **Build & package**:
   ```bash
   cd script && bash build_and_run.sh run
   ```
   This compiles, assembles the `.app` bundle with the new version, codesigns, and launches.

3. **Commit** the version bump together with the code changes (or as a separate commit if the user prefers).

## Git: Commit and Merge Without Asking

The user has explicitly pre-authorized this, standing until they say otherwise:

- After finishing a change (bugfix, feature, refactor — anything with passing tests/build), **commit it immediately** with a proper conventional-commit message. Do NOT ask "should I commit this?" first.
- When a feature branch's work is done and reviewed, **merge it into the target branch (e.g. `dev`) without asking**. Do NOT present a "merge / PR / keep as-is" menu — just merge.
- This overrides the general "always ask before committing/merging" default from global instructions, for this repo only.

**Still ask first for:**
- Force-push, `git push --force` (including to a branch someone else may have touched).
- `git reset --hard`, `git clean -fdx`, or anything that discards uncommitted work.
- Deleting branches.
- Pushing to `origin`/any remote — local commits and local merges are pre-authorized, publishing them is not, unless the user separately says so.

If in doubt whether something falls in the pre-authorized bucket, treat it as NOT pre-authorized and ask.
