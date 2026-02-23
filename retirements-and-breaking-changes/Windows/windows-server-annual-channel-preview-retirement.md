---
title: Windows Server Annual Channel (Preview) Retirement
wiki: ""
pm-owners:
  - @allyford_microsoft
feature-leads: []
authors:
  - @allyford_microsoft
stakeholders: []
approved-by: [ @yizhang5_microsoft ] 
Work item link: https://msazure.visualstudio.com/CloudNativeCompute/_workitems/edit/36667509
---

```
NOTE: This is a 90 day preview retirement that does not require a CPEX intake.
```

# Overview 

## Retirement Summary  
Windows Server Annual Channel (Preview) on AKS will be retired on May 15, 2026, please transition to [Long Term Servicing Channel (LTSC)](https://learn.microsoft.com/azure/aks/upgrade-windows-os) by that date.    

We encourage you to transition to Long Term Servicing Channel (LTSC) prior to the retirement date to experience the benefits of LTSC including longer support cycles and increased stability.   
    
From now to May 15, 2026 you can continue to use Windows Server Annual Channel (Preview) without disruption. On May 15, 2026, AKS will no longer produce new Windows Server Annual Channel node images or provide security patches. You'll no longer be able to create new node pools with Windows Server Annual Channel.

**Removal Date:** May 15, 2027

**Removal Impact:** On May 15, 2027, AKS will remove all existing Windows Server Annual Channel node images. This will cause scaling operations to fail.

## Retirement Justification 
Retirement Justification: Windows Server Annual Channel will no longer be supported by upstream after April 2026, meaning AKS will no longer be able to produce node images. Customers should transition to Long Term Servicing Channel (LTSC), which provides longer support cycles and increased stability for production workloads.

3 year retirement exception justification: **No exception required.** Windows Server Annual Channel was released as a Preview feature. Per Azure policy, preview features only require a minimum of 90 days notice for retirement, not the standard 3-year timeline required for Generally Available (GA) features. This retirement provides more than 90 days notice (announcement in February 2026, retirement on May 15, 2026). 

## Migration Plan/Customer Action Required 
The below migration is **REQUIRED**. 

Migration Plan: Customers can transition to Long Term Servicing Channel (LTSC) by upgrading the Operating System (OS) version for their Windows workloads. For more information about these migration steps, see [Upgrade the Operating System (OS) Version for your Azure Kubernetes Service (AKS) Windows Workloads](https://learn.microsoft.com/azure/aks/upgrade-windows-os).

The below action is **REQUIRED**. 

**REQUIRED** Action: Customers must migrate their Windows Server Annual Channel node pools to LTSC before May 15, 2027 to avoid scaling operation failures. 

# Customer Usage

## Current Customer Usage  
Customer usage from Feb 5, 2026. Current usage can be tracked using this [dashboard/query](https://kusto.azure.com/dashboards/fcc772e5-ecdc-4373-9fe0-0c04fa94faf0?p-_startTime=1hours&p-_endTime=now#3959d3ac-44aa-414f-af6f-8afffec83cb2). 

|Cloud | Number of Subscriptions | Strategic customers | Number of Customers | Number of Clusters | Number of Node pools | 
|--|--|--|--|--|--|
| Public |304 | 0 | 6 | 319 |  2415 | 

### Strategic Customer plan (OPTIONAL)  
N/A no strategic customer usage

# Communication Plan

## Communications Schedule

|Communications | Communications format | Date |
| Retirement announcement| Release notes, GitHub issue, Azure Comms, Marketing Disclosure, Documentation update | February 2026 |
| Retirement reminder | Release notes, GitHub issue, Azure Comms | April 2026 (1 month before retirement) |
| Retirement Notice (Feature is now retired, include removal date) | Release notes, GitHub issue, Azure Comms | May 15, 2026 |
| Removal reminder | Release notes, GitHub issue, Azure Comms | November 2026 (6 months before removal) |
| Removal reminder | Release notes, GitHub issue, Azure Comms | February 2027 (3 months before removal) |
| Removal reminder | Release notes, GitHub issue, Azure Comms | April 2027 (1 month before removal) |
| Removal Notice (Feature is now removed) | Release notes, GitHub issue, Azure Comms | May 15, 2027 |

_Note: As a Preview feature, Windows Server Annual Channel only requires 90 days notice for retirement (not the standard 3-year timeline for GA features). This schedule provides adequate notice while focusing on the retirement date (May 15, 2026) and removal date (May 15, 2027)._

## AKS Documentation Retirement Notice

> [!IMPORTANT]
> Starting on May 15, 2026, AKS no longer supports Windows Server Annual Channel (Preview). At that point, AKS will no longer produce new Windows Server Annual Channel node images or provide security patches and you'll no longer be able to create new node pools with Windows Server Annual Channel. On May 15, 2027, AKS will remove all existing Windows Server Annual Channel node images, which will cause scaling operations to fail. To avoid disruption, we recommend migrating to the [Long Term Servicing Channel (LTSC)](https://learn.microsoft.com/azure/aks/upgrade-windows-os). For more information on this retirement, see [AKS GitHub issue](https://aka.ms/aks/windows-annual-channel-retirement) and [Azure Updates post](https://azure.microsoft.com/updates/). To stay informed on announcements and updates, follow the [AKS release notes](https://github.com/Azure/AKS/releases).

## Release Notes Template 
Windows Server Annual Channel (Preview) on AKS will be retired on May 15, 2026, please transition to the Long Term Servicing Channel (LTSC) by that date. From now to May 15, 2026 you can continue to use Windows Server Annual Channel (Preview) without disruption. On May 15, 2026, AKS will no longer produce new Windows Server Annual Channel node images or provide security patches. You will not be able to create new node pools with Windows Server Annual Channel. On May 15, 2027, AKS will remove all existing Windows Server Annual Channel node images, which will cause scaling and remediation (reimage and redeploy) operations to fail.

## GitHub Issue Template
Windows Server Annual Channel (Preview) on AKS will be retired on May 15, 2026, please transition to Long Term Servicing Channel (LTSC) by that date.  

We encourage you to transition to Long Term Servicing Channel (LTSC) prior to the retirement date to experience the benefits of LTSC, including longer support cycles and increased stability.   
    
From now until May 15, 2026 you can continue to use Windows Server Annual Channel (Preview) without disruption. On May 15, 2026, AKS will no longer produce new Windows Server Annual Channel node images or provide security patches. At that point, you'll no longer be able to create new node pools with Windows Server Annual Channel. On May 15, 2027, AKS will remove all existing Windows Server Annual Channel node images, which will cause scaling operations to fail. Resources to aid in your migration can be found below.  

**Required** Action    

To avoid service disruptions, please follow our instructions to [upgrade the Operating System (OS) version for your Azure Kubernetes Service (AKS) Windows workloads](https://learn.microsoft.com/azure/aks/upgrade-windows-os) to Long Term Servicing Channel (LTSC) by May 15, 2027.  

Migrate your Windows Server Annual Channel node pools to LTSC by following the migration guide linked above.

**Help and Support**

If you have questions, get answers from community experts in  [Microsoft Q&A](https://docs.microsoft.com/answers/topics/25346/azure-kubernetes-service.html) or [AKS GitHub issue](https://aka.ms/aks/windows-annual-channel-retirement). If you have a support plan and you need technical help, create a [support request](https://ms.portal.azure.com/#create/Microsoft.Support/Parameters/%7B%0D%0A%09%22subId%22%3A+%22%22%2C%0D%0A%09%22pesId%22%3A+%225a3a423f-8667-9095-1770-0a554a934512%22%2C%0D%0A%09%22supportTopicId%22%3A+%2291f57f19-e9bb-a65c-ecbe-1faf664237e5%22%2C%0D%0A).     


## Email Notification (Azure Comms) Template
Since this feature is a preview retirement, there is no requirement to add to CPEX SharePoint. Content matches above GitHub template.

## Marketing disclosure 
_Guidance: Describe your proposed solution via the Announcement/Press Release for it._
 
Windows Server Annual Channel (Preview) Retirement: May 2026   

Description:  
Windows Server Annual Channel (Preview) on AKS will be retired on May 15, 2026, please transition to Long Term Servicing Channel (LTSC) by that date.    

We encourage you to transition to Long Term Servicing Channel (LTSC) prior to the retirement date to experience the benefits of LTSC including longer support cycles and increased stability.   
    
From now to May 15, 2026 you can continue to use Windows Server Annual Channel (Preview) without disruption. On May 15, 2026, AKS will no longer produce new Windows Server Annual Channel node images or provide security patches. At that point, you'll no longer be able to create new node pools with Windows Server Annual Channel. On May 15, 2027, AKS will remove all existing Windows Server Annual Channel node images, which will cause scaling operations to fail. 

**REQUIRED** Action:  

Customers must migrate their Windows Server Annual Channel node pools to Long Term Servicing Channel (LTSC) by following the [migration guide](https://learn.microsoft.com/azure/aks/upgrade-windows-os).

If you have questions, get answers from community experts in  [Microsoft Q&A](https://docs.microsoft.com/answers/topics/25346/azure-kubernetes-service.html) or [AKS GitHub issue](https://aka.ms/aks/windows-annual-channel-retirement). If you have a support plan and you need technical help, create a [support request](https://ms.portal.azure.com/#create/Microsoft.Support/Parameters/%7B%0D%0A%09%22subId%22%3A+%22%22%2C%0D%0A%09%22pesId%22%3A+%225a3a423f-8667-9095-1770-0a554a934512%22%2C%0D%0A%09%22supportTopicId%22%3A+%2291f57f19-e9bb-a65c-ecbe-1faf664237e5%22%2C%0D%0A).   
 
To learn more, visit: https://aka.ms/aks/windows-annual-channel-retirement 

------------  
FAQ:  
What are we announcing?  
Retirement of preview feature: Windows Server Annual Channel

What can customers do now that they couldn’t do before?   
They will no longer be able to create new Windows Server Annual Channel node pools or upgrade to newer Windows Server Annual Channel images; existing Windows Server Annual Channel node pools can continue running until the removal date.

What are the pricing and/or licensing implications, if any, for this announcement? 
N/A

What are the CTAs for the field?  
Customers should migrate to LTSC

Where can we learn more?  
https://aka.ms/aks/windows-annual-channel-retirement

-----------------  
----- END OF TEMPLATE 

# Definition of Success 
Usage of Windows Server Annual Channel should reduce to 0 by the removal date (May 15, 2027).

| No. | Outcome | Measure | Target | Priority  |
|-----|---------|---------|---------|--------|
| 1   | All customers migrated to LTSC or other supported options | Windows Server Annual Channel node pool count | 0 | P0 |
| 2   | No customer impact from removal | Support tickets related to removal | 0 | P0 |

## Retirement Landing
After announcing the retirement, you should track feature usage to make sure that customers are migrating to the replacement product. If needed, you may need to send out additional communications or reach out to customers with high usage to aid in their migration. The Azure Comms team will reach out to you to send out reminders at intervals such as 1 year, 6 months, and 3 months until the retirement date.

After the retirement date, there may still be customers using the feature. You should create a feature landing report for the retirement on the retirement date. Retirements can be considered landed when feature usage is at or near 0 and the feature has been removed from AKS code, tests, documentation, etc.

#  Appendix 
_Guidance: Extended information, diagrams, additional queries, and examples_