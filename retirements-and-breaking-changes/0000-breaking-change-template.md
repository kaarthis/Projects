---
title: template
wiki: ""
pm-owners: []
feature-leads: []
authors: []
stakeholders: []
approved-by: [] 
Work item link: []
---

```
Breaking Change Guidance and Links: 
- The below template is for preparing breaking change content and justification for AKS Leads and Marketing approval.  
- Breaking changes typically require 90 days notice from announcement before the change can be made.  To understand what notice period is needed for your breaking change, see [AKS Retirement Scenarios and Requirements](https://microsoft.sharepoint.com/:w:/t/APEXProgram/EWezmtaQICRNhgBqMPDdhdEBPnXHlL9R5AREijaOXAocjg?e=ijiFP6). 
- The official CPEX Breaking Change process can be found at [aka.ms/CPEXBreakingChangesProcess](https://aka.ms/CPEXBreakingChangesProcess). 
- Required approvals include: AKS Leads (same as PRD) and Breaking Change Board. See office hours at: [aka.ms/CPEXBreakingChangesProcess](https://aka.ms/CPEXBreakingChangesProcess) or contact [azbreakchangereview@microsoft.com](mailto:azbreakchangereview@microsoft.com).
```

# Breaking Change Proposal for [ADD NAME OF CHANGE]

## Summary of Breaking Change 
_Guidance: Provide a description of the change that you're making. What can customers no longer do? Is there an API breaking change? How will customers be impacted when the removal happens?_ 

## Customer Impact
_Guidance: Provide data about the customer impact of the breaking change. Include data such as impacted customers, subscriptions, S500 customers, cluster/nodepool/node count, etc._ 

## Migration Plan/Customer Action Required 
_Guidance: Provide information on how a customer can migrate to the recommended alternative. And is there any other action customers need to perform to avoid workload breakage._

The below migration is [REQUIRED/RECOMMENDED] (select one). 

Migration Plan: Customers can transition to [Replacement Product] by [Migration Steps]. For more information about these migration steps, see [aka.ms/aks/feature-name-breaking-change-migration](aka.ms link to migration guide).

The below action is [REQUIRED/RECOMMENDED] (select one). 

[RECOMMENDED/REQUIRED] Action: Customers can [Reduce impact, prepare for breaking change, etc.] by [Action]. 

## Communication Plan
_Guidance: Each breaking change should include communications to impacted customers. This includes [AKS release notes](https://github.com/azure/aks/releases), [AKS Github Issue](https://github.com/Azure/AKS/issues), and [Azure Comms](https://msazure.visualstudio.com/CloudNativeCompute/_wiki/wikis/CloudNativeCompute.wiki/793118/Preparing-Your-Azure-Service-Notification-(Azure-Comms)). Use this section to outline the communications schedule and content._ 

**Do not publish any of these communications until you have breaking change plan approval and the breaking change dates are finalized.** 

### Communications Schedule
_Guidance: Provide a schedule for when announcements and reminders will be sent to affected customers._

|Communications | Communications format | Date |
|--|--|--|
| Breaking Change announcement| Release notes, Github issue, Azure Comms, Documentation update | [ADD Breaking Change announcement DATE, typically 90 days before breaking change] |
| Breaking change reminder | Release notes, Github issue, Azure Comms | [30 days before breaking change date] |
| Breaking Change Notice (Feature is now removed/broken)| Release notes, Github issue, Azure Comms | [Breaking change date] |

_Note: The above schedule assumes a 90 day breaking change timeframe. If your scenario requires more than 90 days notice, you'll need to adjust accordingly. See [AKS Retirement Scenarios and Requirements](https://microsoft.sharepoint.com/:w:/t/APEXProgram/EWezmtaQICRNhgBqMPDdhdEBPnXHlL9R5AREijaOXAocjg?e=ijiFP6) or contact the Breaking Change Board for questions. Office hours at: [aka.ms/CPEXBreakingChangesProcess](https://aka.ms/CPEXBreakingChangesProcess) or contact [azbreakchangereview@microsoft.com](mailto:azbreakchangereview@microsoft.com). _

### AKS Documentation Notice
_Guidance: You should add a Breaking Change notice to any AKS public documentation that uses the feature. The recommended way to do this is to add a file to the "includes > retirement notices" section. See [content contributor guide](https://review.learn.microsoft.com/help/contribute/reusable-content-repo-how-to?branch=main&source=docs) for details._

> [!IMPORTANT]
> Starting on [January 12, 2027], AKS no longer supports [retiring feature name]. [Explain expected customer impact such as data loss, workload breakage, can no longer scale, etc.] To avoid disruption, we recommend migrating to [replacement feature, including link to migration guidance]. For more information on this retirement, see [AKS GitHub issue](add link to retirement GitHub issue) and [Azure Updates post](add link to retirement Azure Updates post). To stay informed on announcements and updates, follow the [AKS release notes](https://github.com/Azure/AKS/releases).

### Release Notes Template 
_Guidance: Provide example release notes that you will publish regarding this breaking change._

[Feature/Service/Product Name with link to AKS documentation] will be retired on DAY MONTH YEAR [Breaking Change Date], please transition to [Replacement Product](Link to migration guidance) by that date. For more information about this breaking change, see [aka.ms/aks/feature-name-breaking-change].

-----END OF TEMPLATE 

CAUTION: The above aka.ms link should link to your github issue. **Do not create a Github issue until you have breaking change plan approval and the breaking change dates are finalized.** 

### Github Issue Template
_Guidance: This content will be used in your github issue on AKS Github. It should match your email content._

[Feature/Service/Product Name w/ link to AKS documentation] will be retired on DAY MONTH YEAR [Breaking Change Date], please transition to [Replacement Product] by that date.  

(Insert reasoning for breaking change – New Features, Improvement Performance, Security). We encourage you to transition to [Replacement Product] prior to the breaking change date to experience the new capabilities of [Replacement Product] including [insert 1-3 new benefits available in the replacement product].   
    
From now to [Breaking Change Date] you can continue to use [Feature/Service/Product Name] without disruption. On [Breaking Change Date] (Insert expected customer impact such as data loss, workload breakage, can no longer scale, etc.). Resources to aid in your migration can be found below.

To avoid service disruptions, please follow our instructions to migrate (hyperlink migration instructions here must be a aka.ms link) to [Replacement product] by [Breaking Change Date].

Help and support  

If you have questions, get answers from community experts in  [Microsoft Q&A](https://docs.microsoft.com/answers/topics/25346/azure-kubernetes-service.html) or AKS GitHub [ADD LINK TO GITHUB ISSUE]. If you have a support plan and you need technical help, create a [support request](https://ms.portal.azure.com/#create/Microsoft.Support/Parameters/%7B%0D%0A%09%22subId%22%3A+%22%22%2C%0D%0A%09%22pesId%22%3A+%225a3a423f-8667-9095-1770-0a554a934512%22%2C%0D%0A%09%22supportTopicId%22%3A+%2291f57f19-e9bb-a65c-ecbe-1faf664237e5%22%2C%0D%0A).     

----- END OF TEMPLATE 

CAUTION:  
- **Do not publish your Github issue until you have Breaking change plan approval and breaking change dates are finalized.** 
- Make sure to include the “Announcement” tag 
- Make sure to add to the AKS public Roadmap in the “Retirements” 

### Email Notification (Azure Comms) Template
_Guidance: Establish a query to identify which subscriptions should get the breaking change notifications. Update email template for your breaking change._ 

Create your Email draft in CPEX sharepoint: 
- Access [CPEX Sharepoint](https://microsoft.sharepoint.com/:f:/t/azureretirements/ErqhgB-B6YBFtTld9Hgrd2IBNkT5WIw0LFj_UTjcjeburA?e=6Ucy75) 
- Duplicate the “Blank Email Request Template” 
- Update your copy of the template to include details about your breaking change 
- Add your email template to the “AKS emails” folder. Feel free to use existing emails as an example. 
- Once completed, add email draft below for review 

Email Notification Draft: <ADD LINK HERE> 

## Breaking Change Landing

After announcing the breaking change, you should track feature usage to make sure that customers are migrating to the replacement product. If needed, you may need to send out additional communications or reach out to customers with high usage to aid in their migration.

After the breaking change date, you should create a feature landing report for the breaking change. Breaking changes can be considered landed when feature usage is at or near 0 and the feature has been removed from AKS code, APIs, tests, documentation, etc.

#  Appendix 
_Guidance: Extended information, diagrams, additional queries, and examples_