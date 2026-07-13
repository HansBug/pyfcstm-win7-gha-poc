# Repository Maintenance Guidance

`AGENTS.md` is a symbolic link to this file. Edit `CLAUDE.md` only; never make
the two guidance files diverge.

## Repository Purpose

This repository is an orchestration-only compatibility gate. It builds upstream
software on free GitHub-hosted runners, executes the resulting artifacts in an
offline Windows 7 SP1 x64 QEMU guest, and validates hash-linked evidence.

The repository must not contain:

- source copied from `HansBug/pyfcstm` or `zhougut/fcstm-gui`;
- Windows ISO files, QCOW2 disks, product keys, activation tokens, or UCRT CABs;
- long-lived downloaded binaries or generated guest evidence;
- secrets, private ISO URLs, or unredacted credentials.

Upstream source is checked out at workflow runtime into `_source/<project>`.
Keep that boundary intact when changing the workflow.

## Non-Negotiable Acceptance Contract

Every full verification must prove all of the following in one run:

1. Both upstream sources were checked out by the workflow and their resolved commits are recorded.
2. `pyfcstm.exe` was built on `windows-2022` and passed the host preflight.
3. `fcstm-gui.exe` was built using the upstream documented Windows method.
4. The GUI source and onefile self-checks passed before upload.
5. A fresh Windows 7 SP1 x64 guest booted under QEMU/KVM on `ubuntu-24.04`.
6. The guest installed the documented UCRT compatibility update and ran offline.
7. Both products ran inside the guest; the CLI report says `status=passed`, `total=15`, `passed=15`, and `failed=0`, while the GUI report says `status=passed`, `passed=182`, and `failed=0`.
8. Guest hashes match the hashes recorded by the Windows build jobs.
9. The host evidence collector passed OS, result, hash, report, and artifact-presence checks.

Do not weaken a failing assertion merely to obtain a green workflow. Fix the
underlying compatibility or make the limitation explicit in the README and
evidence contract.

## Workflow Change Rules

- Use only GitHub-hosted labels already accepted by the repository policy (`windows-2022` and `ubuntu-24.04` at present).
- Do not assume a retired `windows-7`, `windows-10`, `ubuntu-18.04`, or `ubuntu-20.04` hosted label exists.
- Keep QEMU/KVM guest execution as the Windows 7 compatibility proof.
- Keep the guest NIC disabled unless network behavior is the explicit subject of a future test.
- Keep ISO URL and digest in Actions settings; never put secrets in workflow logs, README examples, or commits.
- Keep artifacts bounded by retention days and exclude installation media and system disks.
- Pin upstream revisions for release evidence whenever possible; branch names are suitable for exploratory runs only.
- Any runtime dependency workaround must have a comment explaining the Windows 7 loader/runtime reason.

## Evidence Rules

The authoritative evidence is the artifact from the same successful run, not a
host build log copied from an earlier run. Before reporting success, inspect:

- `result.txt`, `failure.txt`, and `os.txt`;
- `hash.txt` and `fcstm-gui-hash.txt`;
- `pyfcstm-verify.log`;
- `pyfcstm-self-check.txt`;
- `fcstm-gui-self-check.json` and `.log`;
- `java-version-guest.txt`;
- both build metadata files;
- `qemu-exit-status.txt`.

When changing a guest script or collector, run the full workflow. Bash syntax,
YAML parsing, and Python compilation are necessary preflight checks but never
substitute for a fresh guest result.

## Documentation Rules

Keep `README.md` synchronized with workflow behavior. A workflow change that
affects inputs, runner labels, upstream refs, runtime dependencies, evidence
files, ISO handling, retention, or acceptance criteria must update the README
in the same change. Preserve:

- the Mermaid end-to-end flow diagram;
- the exact public ISO fallback URLs and Microsoft UCRT URL;
- source/commit provenance and the latest successful run link;
- product-specific guest commands and report requirements;
- licensing and unpatched-Win7 limitations;
- the `CLAUDE.md` / `AGENTS.md` symlink explanation.

Do not claim that a public URL grants Windows media rights. Availability and
licensing are separate concerns.

## Review Checklist

Before pushing a change:

```bash
python - <<'PY'
from pathlib import Path
import yaml
yaml.safe_load(Path('.github/workflows/win7-qemu-poc.yml').read_text())
print('workflow YAML: ok')
PY
bash -n scripts/*.sh
python -m py_compile scripts/*.py
rm -rf scripts/__pycache__
git diff --check
test "$(readlink AGENTS.md)" = CLAUDE.md
```

For a full gate change, dispatch the workflow, wait for all jobs to finish,
download `win7-verification-evidence`, and record the run URL in the review or
release note. Inspect JSON counts rather than relying on a screenshot.

## Safe Git and GitHub Operations

Never use destructive commands such as `git reset --hard` or `git checkout --`
to discard unrelated work. Before state-changing `gh` calls, verify the CLI
identity matches the repository owner and scope tokens to the command. Do not
switch a global GitHub account as a shortcut.
