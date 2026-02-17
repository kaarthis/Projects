---
title: OS Retirement Template
wiki: ""
pm-owners: []
feature-leads: []
authors: []
stakeholders: []
approved-by: [] 
Work item link: []
---

```
OS Retirement Guidance and Links: 
- The below template is for preparing retirement content and justification for AKS Leads and Marketing approval.  
- CPEX retirement trains occur in March and September. We recommend starting retirement tasks at least one month before. 
- The official CPEX retirement process can be found at [aka.ms/cpexretirements](https://aka.ms/cpexretirements). 
```

# Overview 

## OS Retirement Summary  
_Guidance: Update the outline for your retiring OS. This will be the base for your published content in your email comms, release notes, and Github issue._ 

[OS Name and Version] will be retired on DAY MONTH YEAR [Retirement Date], please transition to [Replacement OS Version](Link to Migration guide) by that date.    

(Insert reasoning for retirement – End of upstream support, security concerns, new OS version availability). We encourage you to transition to [Replacement OS Version] prior to the retirement date to continue receiving security updates and support.   
    
From now to [Retirement Date] you can continue to use [OS Name and Version] without disruption. On [Retirement Date], you will no longer be able to create new node pools with [OS Name and Version], and existing node pools will no longer receive security patches or updates. 

On [Removal Date], AKS will remove all existing node images meaning that scaling operations will fail. 

## Retirement Justification 
_Guidance: Provide justification for retiring this OS. Include information about upstream EOL dates and security implications._ 

Retirement Justification: (Insert reasoning for retirement – Upstream End of Life, Security vulnerabilities, Performance improvements in newer versions, alignment with supported OS versions)

Upstream EOL Date: [DATE]

**3 year retirement exception justification:** (If needed, describe why we cannot wait 3 years to retire. This justification will need to be brought to AKS CVP for approval. For OS retirements, this is often tied to upstream EOL dates.) 

```
**SAMPLE JUSTIFICATION: **
COGS and engineering Impact:
Ubuntu 20.04 retirement was shortened from 3 years to 1 year. This reduction in timeframe would result in: 1) removal of ~25TB of VHD storage totaling ~$6,000 in COGS savings 2) saving ~120 engineering hours. This would also prevent AKS from supporting the OS version after Canonical support ends, which then requires added engineering effort to deal with Ubuntu Pro and various maintenance and upgrades associated with keeping the OS version secure and working.

It can be difficult to calculate the following:
1. VHD storage is dependent on number of VHDs and how many replicas. You can access [VHD COGS](https://vnext.s360.msftcloudes.com/blades/spend?blade=Tab:Summary~KPI:TotalSpend~TimeRange:Weekly~_loc:Spend&peopleBasedNodes=jpang_team&global=@JPANG%2BJuan-Lee%20Pang%20(JPANG)&tile=PivotBy:Subscription~_loc:__key__Spend__0).
2. Engineering hours for a VHD in extended support is about 5-15 hours per month more than our standard VHDs.

Security Impact: Ubuntu 22.04 reaches the end of standard support from Canonical in [April 2027](https://ubuntu.com/about/release-cycle). This means that only customers with Ubuntu Pro will receive security patches until April 2032. Existing Ubuntu 22.04 node pools will be unsupported by AKS when kubernetes version 1.35 reaches end of life on March 31, 2027. This means that these customers will not receive [patch releases](https://learn.microsoft.com/azure/aks/supported-kubernetes-versions) for their kubernetes version including fixes for security vulnerabilities or major bugs after March 31, 2027.

LTS Support Impact:
Since Ubuntu 22.04 will retire on April 30, 2027, there are some LTS scenarios which would cause customers to reach the end of their OS support during their LTS support. In these scenarios, we'll require customers to upgrade their OS version to Ubuntu 24.04 before they can enroll in LTS. See scenarios below:

| kubernetes version | supported ubuntu version | EOL | LTS EOL | LTS Support Statement |
|--|--|--|--|--|
|1.33 | Ubuntu 22.04 default, Ubuntu 24.04 supported | June 2026 | June 2027 | To enroll in LTS, customers will need to update their node pools to use Ubuntu 24.04 |
| 1.34 | Ubuntu 22.04 default, Ubuntu 24.04 supported | Nov 2026 | Nov 2027 | To enroll in LTS, customers will need to update their node pools to use Ubuntu 24.04 |
| 1.35 | Ubuntu 24.04 default, Ubuntu 22.04 supported for rollback | Mar 2027 | Mar 2028| To enroll in LTS, customers will need to update their node pools to use Ubuntu 24.04 |
| 1.36 | Ubuntu 24.04 default, Ubuntu 22.04 NOT supported |July 2027 | July 2028| To enroll in LTS, customers will need to update their node pools to use Ubuntu 24.04 |

Strategic Customer Impact: 
There are currently 256 AzLinux 2 Strategic (S500) customers, and 191 of them (approximately 75%) have initiated their migration to the newest OS version (Azure Linux 3.0). We are actively engaging with SAP, BMW, and SHEIN regarding their migration processes.
```

## Migration Plan/Customer Action Required 
_Guidance: Provide information on how a customer can migrate to the recommended alternative OS version. Include any important pre-requisites for migration (for example, minimum kubernetes version)._

The below migration is [REQUIRED]. 

Migration Plan: Customers can transition to [Replacement OS Version] by creating new node pools [AND/OR updating existing node pools] with the recommended OS version and migrating workloads. For more information about these migration steps, see [aka.ms/aks/os-name-retirement-migration](aka.ms link to migration guide).

```
**Sample Migration Plan:**
There are two ways for customers to migrate to Ubuntu 24.04:

1. Default OS SKU: If you are using a default OS SKU such as `Ubuntu`, you'll automatically migrate to Ubuntu 24.04 when you upgrade your kubernetes version to 1.35+. No manual changes are required to migrate to a new OS version.

2. Versioned OS SKU: If you are using a versioned OS SKU such as `Ubuntu2204`, you'll need to update your OS SKU on your node pool to migrate to Ubuntu 24.04. This can be done by specifying `--os-sku Ubuntu` if you are using kubernetes version 1.35+, or by specifying `--os-sku Ubuntu2404` if you are using kubernetes version 1.32+.

LTS Scenarios: If you want to use LTS in kubernetes version 1.33-1.34, you'll need to update your node pool to specify `--os-sku Ubuntu2404` since OS SKU `Ubuntu` will default to Ubuntu 22.04. To use LTS in 1.33+, you cannot specify `--os-sku Ubuntu2204`.
```

# Customer Usage

## Current Customer Usage  
_Guidance: Update the below table with current OS usage data. You will need a SAW to access usage data in non-public clouds._

Customer usage from [DATE]. Current usage can be tracked using this [dashboard/query](link). 

|Cloud | Number of Subscriptions | Strategic customers | Number of Customers | Number of Clusters | Number of Node pools | Number of Nodes |
|--|--|--|--|--|--|--|
| Public |
| Fairfax |
| Mooncake |

TIPS: 
- To query strategic customers, use: where Strategic400Flag == 'Yes' 
- [Example retirement dashboard](https://dataexplorer.azure.com/dashboards/fcc772e5-ecdc-4373-9fe0-0c04fa94faf0?p-_startTime=1hours&p-_endTime=now#03a84a49-71bb-4458-913d-b985b5834299)
- Air-gapped cloud usage is not query-able by AKS PM. Contact Daxa Patel <daxapatel@microsoft.com> for help.
- For OS retirements, focus on node pool and node counts as these are most relevant.

### Strategic Customer plan (OPTIONAL)  
_Guidance: If your OS version includes significant usage by strategic customers, use this section to outline which strategic customers are using the OS. Include your plan to ensure those strategic customers are notified and aware of the retirement._

Strategic Customers include: [Table with strategic customers and their usage numbers]. 

Plan to notify Strategic Customers: 

# Communication Plan

## Communications Schedule
_Guidance: Provide a schedule for when announcements and reminders will be sent to affected customers. For OS retirements, align your schedule with upstream EOL dates when possible._

|Communications | Communications format | Date |
| --- | --- | --- |
| Retirement announcement| Release notes, Github issue, Azure Comms, Marketing Disclosure, Documentation update | [ADD Retirement announcement DATE] |
| Retirement reminder | Release notes, Github issue, Azure Comms | [6 months before retirement date] |
| Retirement reminder | Release notes, Github issue, Azure Comms | [3 months before retirement date] |
| Retirement reminder | Release notes, Github issue, Azure Comms | [1 month before retirement date] |
| Retirement Notice (OS is now retired, new node pools cannot be created) | Release notes, Github issue, Azure Comms | [Retirement date] |
| Removal Notice (OS image is now removed, existing node pools will experience scaling issues) | Release notes, Github issue, Azure Comms | [Removal Date] |

_Note: OS retirement timelines may differ from standard 3-year retirements due to upstream EOL dates. Adjust the schedule to align with upstream support lifecycles and security considerations._

## AKS Documentation Retirement Notice
_Guidance: You should add a retirement notice to any AKS public documentation that uses the retiring feature. The recommended way to do this is to add a file to the "includes" section. See [content contributor guide](https://review.learn.microsoft.com/help/contribute/reusable-content-repo-how-to?branch=main&source=docs) for details._

> [!IMPORTANT]
> Starting on [January 12, 2027], AKS no longer supports [retiring feature name]. [Explain expected customer impact such as data loss, workload breakage, can no longer scale, etc.] To avoid disruption, we recommend migrating to [replacement feature, including link to migration guidance]. For more information on this retirement, see [AKS GitHub issue](add link to retirement GitHub issue) and [Azure Updates post](add link to retirement Azure Updates post). To stay informed on announcements and updates, follow the [AKS release notes](https://github.com/Azure/AKS/releases).

## Release Notes Template 
_Guidance: Provide example release notes that you will publish regarding this OS retirement._

[OS Name and Version] will be retired on DAY MONTH YEAR [Retirement Date], please transition to [Replacement OS Version](Link to migration guidance) by that date. After the retirement date, you will not be able to create new node pools with [OS Name and Version], and existing node pools will no longer receive security patches or updates. For more information about this retirement, see [aka.ms/aks/os-name-retirement]. 

-----END OF TEMPLATE 

CAUTION: The above aka.ms link should link to your GitHub issue. **Do not create a GitHub issue until you have retirement plan approval and the retirement dates are finalized.** 

## GitHub Issue Template
_Guidance: This content will be used in your GitHub issue on AKS GitHub. It should match your email content._

[OS Name and Version] will be retired on DAY MONTH YEAR [Retirement Date], please transition to [Replacement OS Version] by that date.  

(Insert reasoning for retirement – Upstream End of Life, security concerns, new OS version availability). We encourage you to transition to [Replacement OS Version] prior to the retirement date to continue receiving security updates and support.   
    
From now to [Retirement Date] you can continue to use [OS Name and Version] without disruption. On [Retirement Date], you will no longer be able to create new node pools with [OS Name and Version], and existing node pools will no longer receive security patches or updates. Resources to aid in your migration can be found below.  

[Recommended/Required] (select one) Action    

To avoid security vulnerabilities and service disruptions, please follow our instructions to migrate (hyperlink migration instructions here must be a aka.ms link) to [Replacement OS Version] by [Retirement Date].  

[Add migration instructions and other recommended/required action here]. 

Help and support  

If you have questions, get answers from community experts in [Microsoft Q&A](https://docs.microsoft.com/answers/topics/25346/azure-kubernetes-service.html) or AKS GitHub [ADD LINK TO GITHUB ISSUE]. If you have a support plan and you need technical help, create a [support request](https://ms.portal.azure.com/#create/Microsoft.Support/Parameters/%7B%0D%0A%09%22subId%22%3A+%22%22%2C%0D%0A%09%22pesId%22%3A+%225a3a423f-8667-9095-1770-0a554a934512%22%2C%0D%0A%09%22supportTopicId%22%3A+%2291f57f19-e9bb-a65c-ecbe-1faf664237e5%22%2C%0D%0A).   

Learn more about service retirements that may impact your resources in the Azure Retirement Workbook. Please note that retirements may not be visible in the workbook for up to two weeks after being announced.    

----- END OF TEMPLATE 

CAUTION:  
- **Do not publish your Github issue until you have retirement plan approval and retirement dates are finalized.** 
- Make sure to include the "Announcement" tag 
- Make sure to add to the AKS public Roadmap in the "Retirements" 

## Email Notification (Azure Comms) Template
_Guidance: Establish a query to identify which subscriptions should get the retirement notifications based on OS usage. Update email template for your retirement._ 

Create your Email draft in CPEX sharepoint: 
- Access [CPEX Sharepoint](https://microsoft.sharepoint.com/:f:/t/azureretirements/ErqhgB-B6YBFtTld9Hgrd2IBNkT5WIw0LFj_UTjcjeburA?e=6Ucy75) 
- Duplicate the "Blank Email Request Template" 
- Update your copy of the template to include details about your OS retirement 
- Add your email template to the "AKS emails" folder. Feel free to use existing emails as an example. 
- Once completed, add email draft below for review 

Email Notification Draft: <ADD LINK HERE> 

## Marketing disclosure 
_Guidance: Describe your proposed solution via the Announcement/Press Release for it._
 
<OS Retirement>: <RELEASE> (<owner>)   

Description:  
[OS Name and Version] will be retired on DAY MONTH YEAR [Retirement Date], please transition to [Replacement OS Version] by that date.    

(Insert reasoning for retirement – Upstream End of Life, security concerns, new OS version availability). We encourage you to transition to [Replacement OS Version] prior to the retirement date to continue receiving security updates and support.   
    
From now to [Retirement Date] you can continue to use [OS Name and Version] without disruption. On [Retirement Date], you will no longer be able to create new node pools with [OS Name and Version], and existing node pools will no longer receive security patches or updates. 

[RECOMMENDED/REQUIRED] Action:  

Customers should upgrade their node pools to [Replacement OS Version] to continue receiving security updates and support.

Help and support  

If you have questions, get answers from community experts in [Microsoft Q&A](https://docs.microsoft.com/answers/topics/25346/azure-kubernetes-service.html) or AKS GitHub [ADD LINK TO GITHUB ISSUE]. If you have a support plan and you need technical help, create a [support request](https://ms.portal.azure.com/#create/Microsoft.Support/Parameters/%7B%0D%0A%09%22subId%22%3A+%22%22%2C%0D%0A%09%22pesId%22%3A+%225a3a423f-8667-9095-1770-0a554a934512%22%2C%0D%0A%09%22supportTopicId%22%3A+%2291f57f19-e9bb-a65c-ecbe-1faf664237e5%22%2C%0D%0A).    

To learn more, visit: <<aka.ms LINK>>  

------------  
FAQ:  
What are we announcing?  
What is the upstream EOL date for this OS?
What can customers do now that they couldn't do before?   
What are the pricing and/or licensing implications, if any, for this announcement?   
What are the CTAs for the field?  
Where can we learn more?  
-----------------  
----- END OF TEMPLATE 

# Definition of Success 
_Guidance: Identify the business, customer, and technology outcomes you expect to achieve as a result of announcing this OS retirement. Particularly important to include is expected migration outcomes and at what point in retirement migration is removal of the retired OS acceptable._

Define the measures you will use to gauge progress. 

Ongoing iteration on the outcomes, and how to measure them, will be critical to success.

Consider leveraging experiments to enable data-driven decisions.  

| No. | Outcome | Measure | Target | Priority  |
|-----|---------|---------|---------|--------|
| 1   | Reduce node pool count on retired OS | Track node pool count using retirement dashboard | <X% of current usage by retirement date |   |
| 2   | Reduce node count on retired OS | Track node count using retirement dashboard | <X% of current usage by retirement date |   |
| 3   | Migration to replacement OS | Track node pool count on replacement OS | X% increase in replacement OS adoption |   |

## Retirement Landing
After announcing the retirement, you should track OS usage to make sure that customers are migrating to the replacement OS version. If needed, you may need to send out additional communications or reach out to customers with high usage to aid in their migration. The Azure Comms team will reach out to you to send targeted retirement communications to impacted customers and can help coordinate blog posts, documentation updates, and in-product messaging so that customers clearly understand the retirement timeline and recommended migration path.