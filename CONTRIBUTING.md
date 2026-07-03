# Contributing to mggraph-intune-samples

Thank you for your interest in contributing! This repository contains sample
PowerShell scripts that demonstrate how to use the Microsoft Graph PowerShell SDK
to manage Microsoft Intune. The samples are provided for learning and reference.

## Contributor License Agreement

This project welcomes contributions and suggestions. Most contributions require you
to agree to a Contributor License Agreement (CLA) declaring that you have the right
to, and actually do, grant us the rights to use your contribution. For details,
visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you
need to provide a CLA and decorate the PR appropriately (e.g., status check,
comment). Simply follow the instructions provided by the bot. You will only need to
do this once across all repositories using our CLA.

## Code of Conduct

This project has adopted the [Microsoft Open Source Code of Conduct](CODE_OF_CONDUCT.md).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/)
or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any
additional questions or comments.

## Before you start

> [!IMPORTANT]
> These scripts make changes to Intune configuration and can affect real devices and
> users. **Always run them against a non-production ("test") tenant first.** Never
> test against a production tenant.

## How to contribute

1. **Fork** the repository and create a topic branch from `main`.
2. Follow the coding conventions in [docs/conventions.md](docs/conventions.md).
3. Add the standard copyright header to the top of every new `.ps1` file:

   ```powershell
   <#
   .COPYRIGHT
   Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
   See LICENSE in the project root for license information.
   #>
   ```

4. Run the verification script before opening a pull request:

   ```powershell
   ./scripts/verify.ps1
   ```

5. Keep pull requests small and focused — ideally one sample or fix per PR.
6. Open a pull request and complete the checklist in the PR template.

## Reporting issues and requesting samples

Use the issue templates under **Issues → New issue**:

- **Script sample issue** — report a problem with an existing sample.
- **Sample script request** — request a new sample.
- **Question** — ask a question.

## Trademarks

This project may contain trademarks or logos for projects, products, or services.
Authorized use of Microsoft trademarks or logos is subject to and must follow
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not
cause confusion or imply Microsoft sponsorship. Any use of third-party trademarks or
logos is subject to those third parties' policies.
