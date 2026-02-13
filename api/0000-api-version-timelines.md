# Understanding API Version Timelines

See also: [Feature Development Process in Collaboration With API Release](https://msazure.visualstudio.com/CloudNativeCompute/_wiki/wikis/CloudNativeCompute.wiki/365430/Feature-Development-Process-in-Collaboration-With-API-Release)

## Important time points

- **RP Cutoff** — Deadline is when the code must be merged into repo [aks-rp](https://dev.azure.com/msazure/CloudNativeCompute/_git/aks-rp).
  Cannot give a clear date as the release cycle of official release is not fixed. People can check the email with the title
  `RE: AKS RP Release Update v20204xxxx` to see the progress of the current official release, it will also provide predictions on the next release.
- **Swagger Cutoff** — Deadline is when the Swagger changes must be merged into the dev branch.
- **CLI Cutoff** — Deadline when CLI changes must be merged into azure-cli.

## Sample Timeline

Assume that the month corresponding to the API version is X. The following is a rough estimate based on normal conditions.

### Stable API

| Time | Event | Dev |
| --- | --- | --- |
| X month - 1st week | Base data model related to the API version is cloned | Dev could start working on RP frontend |
| X month - 3rd week | Dev branch of swagger is created | Dev could start working on swagger changes |
| X month - 4th week | RP/swagger cutoff | Deadline for RP/swagger change |
| X+1 month - 1st week | Swagger release | |
| X+1 month - 3rd week | SDK release, bumped SDK and default API version in official azure-cli | Dev could start working on CLI changes |
| X+1 month - 4th week | CLI cutoff | Deadline for CLI change |

### Preview API

| Time | Event | Dev |
| --- | --- | --- |
| X month - 1st week | Base data model related to the API version is cloned | Dev could start working on RP frontend |
| X month - 3rd week | Dev branch of swagger is created | Dev could start working on swagger changes |
| X month - 4th week | RP/swagger cutoff | Deadline for RP/swagger change |
| X+1 month - 3rd week | Swagger release, bumped SDK and default API version in cli-extensions/aks-preview | Dev could start working on CLI changes, no deadline for CLI change |