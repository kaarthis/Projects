# Title
**Author(s)**:
**PRD**: <link>
**Design doc:** <link>

## Brief description of why this change is needed

Simple 1-2 sentence description of how the proposed API change solves the problem posed by the PRD. Why choose this approach?

## REST API proposal

Include a Swagger snippet describing the REST API change you're going to make. Please ensure that the documentation is complete. This snippet should be the change you put into the actual Swagger documentation and of production quality. If uncertain about Swagger format, see [AKS Swagger](https://github.com/Azure/azure-rest-api-specs/tree/main/specification/containerservice/resource-manager/Microsoft.ContainerService/stable)

**If this is for a GA API, or GA-ing a feature**: All [LRB GA criteria](https://msazure.visualstudio.com/CloudNativeCompute/_wiki/wikis/CloudNativeCompute.wiki/388576/LRB-Checklist-Template?anchor=ga-checklist) items that can be done prior to GA-ing the API itself must be done. This includes quality, QOS, scalability, buildout (including sovereign), etc - see the LRB list for the full set.

### Review: 
- https://github.com/microsoft/api-guidelines/blob/vNext/azure/Guidelines.md
- https://armwiki.azurewebsites.net/api_contracts/guidelines/openapi.html
- https://armwiki.azurewebsites.net/api_contracts/guidelines/rpc.html
- https://github.com/Azure/azure-resource-manager-rpc/tree/master/v1.0

## CLI Proposal (optional)

## Conclusion

**Approvers**: At least 2 Eng and 1 PM **from AKS API Review alias (aksarb)**

| AKS ARB | Approval Status | Notes |
| -- | -- | -- |
|  |  |  |
|  |  |  |
|  |  |  |

## Terraform support:
- Once a feature is added in preview API, the feature owner needs to list all the prerequisites and relevant CLI commands in the API page. We also need to update the prerequisites on GA if the feature has more functionality.
- Azure terraform team checks the API list every month and helps managing aks features working via terraform. 
- The ETA for terraform support is 3 months after public preview. If there are functionality updates on GA, they will be supported on terraform 3 months after GA.

Example:
Feature name | Public preview API |Terraform support for preview | GA API | Terraform support for GA
-|-|-|-|-
KMS|2022-03-01-preview API|2022-06| 2022-06-01 API | 2022-09|

Feel free to reach @<Fuming Zhang> @<Coco Wang🌈> in case any concern.

You can refer to the [example](https://dev.azure.com/msazure/CloudNativeCompute/_wiki/wikis/CloudNativeCompute.wiki/338280/Move-KMS-to-GA?anchor=terraform-part%3A) for more details 
