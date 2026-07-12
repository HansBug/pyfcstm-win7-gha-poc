# pyfcstm Windows 7 GitHub Actions PoC

This repository contains only orchestration for a Windows 7 compatibility
gate. It does not vendor, mirror, submodule, or commit `pyfcstm` source code.
The build job checks out `HansBug/pyfcstm@main` into its temporary runner
workspace, creates `dist/pyfcstm.exe`, and passes only the EXE plus one
upstream DSL fixture to the guest job as a short-lived Actions artifact.

## What the workflow proves

The workflow uses only GitHub-hosted runners:

1. `windows-2022` checks out `HansBug/pyfcstm@main` and runs its existing
   Windows standalone build path with Python 3.7. The PoC pins
   `PyInstaller==4.10`: its documentation still says Windows 7 should work,
   while PyInstaller 5 and later list Windows 8 as the support floor.
2. `ubuntu-24.04` requires `/dev/kvm`, installs QEMU, and creates an empty
   Windows 7 virtual disk for this run.
3. QEMU boots a real Windows 7 SP1 x64 installation from an authorized ISO.
   The guest has no virtual NIC.
4. Windows Setup reads `Autounattend.xml`, installs unattended, auto-logs in
   once, runs the EXE from an offline payload CD, writes evidence to a FAT
   result disk, and shuts down.
5. The Linux host accepts a run only when the returned caption names Windows 7
   and the returned values are exactly `Version=6.1.7601`, `BuildNumber=7601`,
   `ServicePackMajorVersion=1`, `ProductType=1`, and `OSArchitecture=64-bit`.
   The guest's SHA-256 must equal the Windows build artifact, and the CLI
   smoke, PlantUML, and SMT/Z3 inspect commands must succeed.

`ProductType=1` is essential: it rejects Windows Server 2008 R2, which shares
the 6.1 kernel family but is not Windows 7. Requiring a Windows 7 caption also
prevents a componentized Embedded Standard 7 image from being labelled as a
Windows 7 client result.

Until a successful run has produced `win7-verification-evidence`, this
repository must not describe any pyfcstm executable as "Verified on Win7".

## Required configuration

This public repository deliberately contains no Windows installation media,
product key, golden image, or ISO URL. Add these repository settings before
dispatching the workflow:

| Setting | Kind | Value |
| --- | --- | --- |
| `WIN7_ISO_URL` | Actions secret | HTTPS URL to an ISO that the repository owner is authorized to use |
| `WIN7_ISO_SHA256` | Actions secret | SHA-256 of that exact ISO |
| `WIN7_IMAGE_INDEX` | Actions variable | Positive `install.wim` image index for Windows 7 SP1 x64 |
| `WIN7_LOCALE` | Actions variable | ISO UI language in the form `en-US` or `zh-CN`, defaults to `en-US` |

The `workflow_dispatch` form can temporarily replace all three values. This
is useful for testing a new authorized ISO without changing saved settings.
The ISO is downloaded to the ephemeral runner, checked before use, never
cached, and not uploaded as an artifact.

Windows 7 media licensing is not solved by technical automation. Use only
media and a license whose terms permit this use. In particular, do not source
an ISO from a third-party re-distribution, archive, or modified image. Each
run creates a fresh unactivated guest and destroys its disk, rather than
persisting an activated golden image.

## Automation and evidence

The workflow runs weekly and can also receive a `repository_dispatch` event
named `verify-pyfcstm-main`. That event lets an authorized sender trigger the
independent gate after a change in `HansBug/pyfcstm`; it does not make this
repository contain source code. A source-repository release gate would need a
separate, explicit dispatch credential or GitHub App configuration.

On every attempt, the `win7-verification-evidence` artifact retains the serial
log, FAT result image, guest OS report, EXE hash report, and CLI log for 30
days. The ISO and the guest system disk are intentionally excluded.

## Research conclusions

### Old Linux environments

GitHub-hosted runner labels are not an archive. Retired labels such as
`ubuntu-20.04` should not be used as compatibility evidence, and an old
userspace container is not an old kernel. On a current GitHub-hosted Ubuntu
runner, an `ubuntu:18.04` or `ubuntu:20.04` Docker container is a practical
way to *build* against an older glibc/userspace. When execution on the real
old operating system is required, boot that OS in QEMU/KVM instead. The same
GitHub-hosted runner constraint still holds in both cases.

### Windows 7

There is no supported `windows-7` GitHub-hosted runner. A Windows container is
not a substitute: Windows container compatibility is coupled to the host
kernel and cannot provide Windows 7 kernel/user-mode evidence. A QEMU guest on
a current Linux hosted runner is therefore the viable fully automated route.

The runner and product constraints are documented by GitHub and Microsoft:

- [GitHub-hosted runners](https://docs.github.com/en/actions/reference/runners/github-hosted-runners)
- [GitHub Actions limits](https://docs.github.com/en/actions/reference/limits)
- [Windows container version compatibility](https://learn.microsoft.com/en-us/virtualization/windowscontainers/deploy-containers/version-compatibility)
- [Windows version reporting](https://learn.microsoft.com/en-us/windows/win32/sysinfo/operating-system-version)
- [Win32_OperatingSystem properties](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-operatingsystem)
- [PyInstaller 5.13.2 supported Windows versions](https://pyinstaller.org/en/v5.13.2/requirements.html)
- [Packer unattended Windows installations](https://developer.hashicorp.com/packer/guides/automatic-operating-system-installs/autounattend_windows)

The PyInstaller link is why the guest execution is a real compatibility gate:
the documented support floor for that release is Windows 8, so a build that
succeeds on Windows 2022 cannot establish Windows 7 compatibility by itself.
For comparison, [PyInstaller 4.10 requirements](https://pyinstaller.org/en/v4.10/requirements.html)
state that Windows 7 should work, although it was not a supported platform.
