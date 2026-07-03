# GitHub Copilot instructions — mggraph-intune-samples

This repository is a set of **Microsoft Graph PowerShell SDK** samples for managing
**Microsoft Intune**. It is a non-production, learning/reference repo. See
[AGENTS.md](../AGENTS.md) and [docs/conventions.md](../docs/conventions.md) for full
context; this file is a quick pointer for Copilot.

## When generating or editing scripts

- **Language:** Windows PowerShell / PowerShell 7 using the `Microsoft.Graph` and
  `Microsoft.Graph.Beta` modules. Match the style of neighbouring scripts in the same
  folder.
- **Copyright header:** every `.ps1` file must begin with:

  ```powershell
  <#
  .COPYRIGHT
  Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
  See LICENSE in the project root for license information.
  #>
  ```

- **Modules:** import the specific `Microsoft.Graph*` submodule(s) the script needs
  (e.g., `Microsoft.Graph.DeviceManagement`), not the whole SDK.
- **Authentication:** use `Connect-MgGraph` with least-privilege scopes; follow the
  authentication/region comment block used by existing samples. Never hard-code
  secrets, tenant IDs, client secrets, or certificates.
- **Safety:** these scripts change Intune configuration. Add comments reminding users
  to run against a **non-production tenant**. Take extra care with `*_Remove.ps1` /
  `*_Wipe.ps1` / `*_Delete.ps1` samples.

## Verifying

Run `./scripts/verify.ps1` (PSScriptAnalyzer + header check) before proposing a
commit.

## Pull request guardrails

- Keep changes **small and focused** — ideally one sample or fix per PR; avoid
  sweeping unrelated edits.
- Don't reformat or refactor unrelated files.
- Fill in the [PR template](pull_request_template.md).
