# Coding conventions

Conventions for the PowerShell samples in this repository. New and modified scripts
should follow these so the samples stay consistent and easy to learn from.

## File header

Every `.ps1` file must begin with the standard copyright header:

```powershell
<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
#>
```

## Module imports

- Import the **specific** `Microsoft.Graph*` submodule(s) a script needs rather than
  the entire SDK, e.g.:

  ```powershell
  Import-Module Microsoft.Graph.DeviceManagement
  ```

- Use the `Microsoft.Graph.Beta.*` modules only when a sample depends on beta APIs.
- If a script requires a module, you may also declare it with `#requires -module ...`.

## Authentication

- Authenticate with `Connect-MgGraph` using the **least-privilege** scopes needed by
  the sample.
- Keep the existing "region Authentication" comment block that links to the SDK
  installation and authentication guidance.
- **Never** hard-code tenant IDs, client secrets, certificates, or other credentials.

## Naming

- Script names follow the style of the folder they live in (e.g.,
  `DeviceConfiguration_Export.ps1`, `Get-AndroidDeviceOwnerProfiles.ps1`).
- Prefer approved PowerShell verbs (`Get`, `Set`, `New`, `Remove`, `Export`, ...) for
  functions.

## Style

- Favour readability over cleverness — these are teaching samples.
- Comment the intent of each major step.
- Handle errors where it aids the learner (e.g., `-ErrorAction Stop` with a helpful
  message), but don't over-engineer.

## Safety

> [!IMPORTANT]
> These scripts create, modify, or delete Intune configuration and can affect real
> devices and users.

- Design and test samples against a **non-production ("test") tenant** only.
- Never commit exported tenant data or secrets (see [.gitignore](../.gitignore)).
- Clearly document destructive samples (`*_Remove.ps1`, `*_Wipe.ps1`, `*_Delete.ps1`).

## Verifying

Run the repository verification script before committing:

```powershell
./scripts/verify.ps1
```

It runs `PSScriptAnalyzer` and checks that every `.ps1` file has the copyright header.
