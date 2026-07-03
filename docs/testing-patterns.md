# Testing patterns

These are **sample** scripts, so testing is primarily manual and interactive.
There is no automated unit-test suite. Follow the patterns below before you open a
pull request.

## 1. Static verification (required)

Run the repository verification script. It lints every script with
`PSScriptAnalyzer` and confirms each `.ps1` file carries the copyright header:

```powershell
./scripts/verify.ps1
```

If `PSScriptAnalyzer` is not installed:

```powershell
Install-Module PSScriptAnalyzer -Scope CurrentUser
```

## 2. Manual run against a non-production tenant (required)

> [!IMPORTANT]
> These scripts create, modify, or delete Intune configuration and can affect real
> devices and users. **Only run them against a non-production ("test") tenant.**

1. Install the Microsoft Graph PowerShell SDK if needed — see the
   [installation guide](https://learn.microsoft.com/powershell/microsoftgraph/installation).
2. Connect with least-privilege scopes, e.g.:

   ```powershell
   Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All"
   ```

3. Run the sample and confirm it behaves as documented in the folder `README`.
4. For destructive samples (`*_Remove.ps1`, `*_Wipe.ps1`, `*_Delete.ps1`), verify
   against disposable test objects only.
5. Disconnect when finished:

   ```powershell
   Disconnect-MgGraph
   ```

## 3. What to check

- The script imports only the specific `Microsoft.Graph*` submodule(s) it needs.
- No secrets, tenant IDs, or exported tenant data are left in the working tree.
- Output and error handling match the surrounding samples in the same folder.
