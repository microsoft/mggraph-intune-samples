# AGENTS.md

Guidance for AI coding agents and human contributors working in this repository.

## What this repo is

`mggraph-intune-samples` is a collection of **sample PowerShell scripts** that show
how to use the **Microsoft Graph PowerShell SDK** to manage **Microsoft Intune**
(device configuration, compliance, app protection, enrollment, managed devices,
reporting, and more). It is a **non-production, learning/reference** repository: the
scripts are meant to be read, adapted, and run by IT pros against their own tenants.
It produces no build artifact and is not a dependency of other software.

## Repository layout

Each top-level folder groups samples by Intune workload, for example:

| Folder | Area |
|---|---|
| `AndroidEnterprise/`, `AOSPEnrollmentProfileManagement/` | Android enrollment |
| `AppleEnrollment/` | Apple ADE / APNs |
| `AppConfigurationPolicy/`, `AppProtectionPolicy/` | App configuration & protection (MAM) |
| `CompliancePolicy/`, `DeviceConfiguration/`, `SettingsCatalog/` | Policy management |
| `LOB_Application/` | Line-of-business app upload (Win32 / MSIX / iOS / macOS) |
| `ManagedDevices/` | Device queries and actions |
| `ReportExportJobs/` | Intune report export jobs |
| `Permission_Analyzer/` | Graph permission analysis |
| `docs/` | Contributor conventions and testing patterns |
| `scripts/` | Repository tooling (e.g., `verify.ps1`) |

Most folders contain their own `README`/`readme.md` describing the samples.

## Conventions

See [docs/conventions.md](docs/conventions.md) for the full coding conventions. Key
points:

- Every `.ps1` file starts with the standard `.COPYRIGHT` header block.
- Scripts import the specific `Microsoft.Graph*` submodule(s) they need and use the
  documented authentication/region pattern.
- Prefer clarity over cleverness — these are teaching samples.

## Safety rules (important)

> [!IMPORTANT]
> Scripts in this repo **create, modify, or delete Intune configuration** and can
> affect real devices and users. When authoring or testing:
>
> - **Only run against a non-production ("test") tenant.**
> - Never hard-code secrets, tenant IDs, or credentials; never commit exported tenant
>   data (see [.gitignore](.gitignore)).
> - Keep destructive samples (`*_Remove.ps1`, `*_Wipe.ps1`, `*_Delete.ps1`) clearly
>   scoped and documented.

## Verify your changes

Run the verification loop before committing or opening a PR:

```powershell
./scripts/verify.ps1
```

This runs `PSScriptAnalyzer` across all scripts and checks that every `.ps1` file has
the required copyright header.

## Pull requests

- Keep PRs small and focused — ideally one sample or fix per PR.
- Fill in [the PR template](.github/pull_request_template.md).
- Ensure `./scripts/verify.ps1` passes and new scripts include the copyright header.
- See [CONTRIBUTING.md](CONTRIBUTING.md) for the CLA and full process.
