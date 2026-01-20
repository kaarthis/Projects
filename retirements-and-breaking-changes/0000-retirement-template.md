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
Retirement Guidance and Links: 
- The below template is for preparing retirement content and justification for AKS Leads and Marketing approval.  
- CPEX retirement trains occur in March and September. We recommend starting retirement tasks at least one month before. 
- To understand if a CPEX retirement is needed for your feature retirement, see [AKS Retirement Scenarios and Requirements](https://microsoft.sharepoint.com/:w:/t/APEXProgram/EWezmtaQICRNhgBqMPDdhdEBPnXHlL9R5AREijaOXAocjg?e=ijiFP6). 
- The official CPEX retirement process can be found at [aka.ms/cpexretirements](https://aka.ms/cpexretirements). 
```

# Overview 

## Retirement Summary  
_Guidance: Update the outline for your retiring feature. This will be the base for your published content in your email comms, release notes, and Github issue._ 

[Feature/Service/Product Name with link to AKS documentation] will be retired on DAY MONTH YEAR [Retirement Date], please transition to [Replacement Product](Link to Migration guide) by that date.    

(Insert reasoning for retirement – New Features, Improvement Performance, Security. This should be a customer-facing explanation.). We encourage you to transition to [Replacement Product] prior to the retirement date to experience the new capabilities of [Replacement Product] including [insert 1-3 new benefits available in the replacement product].   
    
From now to [Retirement Date] you can continue to use [Feature/Service/Product Name] without disruption. On [Retirement Date] (Insert expected customer impact such as data loss, workload breakage, can no longer scale, etc.). 

## Retirement Justification 
_Guidance: Provide justification for retiring this feature. If an exception to the 3 year timeline is required, provide justification here._ 

Retirement Justification: (Insert reasoning for retirement – New Features, Improvement Performance, Security. This is internal-only so it can include justification such as COGS savings, code simplification, etc.) 

3 year retirement exception justification: (If needed, describe why we cannot wait 3 years to retire. This justification will need to be brought to AKS CVP for approval. Include links to docs with more information if applicable.) 

## Migration Plan/Customer Action Required 
_Guidance: Provide information on how a customer can migrate to the recommended alternative. And is there any other action customers need to perform._

The below migration is [REQUIRED/RECOMMENDED] (select one). 

Migration Plan: Customers can transition to [Replacement Product] by [Migration Steps]. For more information about these migration steps, see [aka.ms/aks/feature-name-retirement-migration](aka.ms link to migration guide).

The below action is [REQUIRED/RECOMMENDED] (select one). 

[RECOMMENDED/REQUIRED] Action: Customers can [Reduce impact, prepare for retirement, etc.] by [Action]. 

# Customer Usage

## Current Customer Usage  
_Guidance: Update the below table with current usage data. Adjust as necessary depending on the feature. For example, if the feature is a cluster-level feature, node pool and node usage data is not necessary. You will need a SAW to access usage data in non-public clouds._

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

### Strategic Customer plan (OPTIONAL)  
_Guidance: If your feature includes significant usage by strategic customers, use this section to outline which strategic customers are using the feature. Include your plan to ensure those strategic customers are notified and aware of the retirement._

Strategic Customers include: [Table with strategic customers and their usage numbers]. 

Plan to notify Strategic Customers: 

# Communication Plan

## Communications Schedule
_Guidance: Provide a schedule for when announcements and reminders will be sent to affected customers._

|Communications | Communications format | Date |
| Retirement announcement| Release notes, Github issue, Azure Comms, Marketing Disclosure, Documentation update | [ADD Retirement announcement DATE] |
| Retirement reminder | Release notes, Github issue, Azure Comms | [2 years before retirement date] |
| Retirement reminder | Release notes, Github issue, Azure Comms | [1 year before retirement date] |
| Retirement reminder | Release notes, Github issue, Azure Comms | [6 months before retirement date] |
| Retirement reminder | Release notes, Github issue, Azure Comms | [3 months before retirement date] |
| Retirement Notice (Feature is now retired, include removal date if applicable) | Release notes, Github issue, Azure Comms | [Retirement date] |
| Removal Notice (Feature is now removed) | Release notes, Github issue, Azure Comms | [Removal Date] |

_Note: The above schedule assumes a 3 year retirement timeframe. If you've gotten an exception to retire your feature in a reduced timeframe, you'll need to adjust the above table accordingly._

## AKS Documentation Retirement Notice
_Guidance: You should add a retirement notice to any AKS public documentation that uses the retiring feature. The recommended way to do this is to add a file to the "includes" section. See [content contributor guide](https://review.learn.microsoft.com/help/contribute/reusable-content-repo-how-to?branch=main&source=docs) for details._

> [!IMPORTANT]
> Starting on [January 12, 2027], AKS no longer supports [retiring feature name]. [Explain expected customer impact such as data loss, workload breakage, can no longer scale, etc.] To avoid disruption, we recommend migrating to [replacement feature, including link to migration guidance]. For more information on this retirement, see [AKS GitHub issue](add link to retirement GitHub issue) and [Azure Updates post](add link to retirement Azure Updates post). To stay informed on announcements and updates, follow the [AKS release notes](https://github.com/Azure/AKS/releases).

## Release Notes Template 
_Guidance: Provide example release notes that you will publish regarding this retirement._

[Feature/Service/Product Name with link to AKS documentation] will be retired on DAY MONTH YEAR [Retirement Date], please transition to [Replacement Product](Link to migration guidance) by that date. For more information about this retirement, see [aka.ms/aks/feature-name-retirement]. 

-----END OF TEMPLATE 

CAUTION: The above aka.ms link should link to your github issue. **Do not create a Github issue until you have retirement plan approval and the retirement dates are finalized.** 

## Github Issue Template
_Guidance: This content will be used in your github issue on AKS Github. It should match your email content._

[Feature/Service/Product Name w/ link to AKS documentation] will be retired on DAY MONTH YEAR [Retirement Date], please transition to [Replacement Product] by that date.  

(Insert reasoning for retirement – New Features, Improvement Performance, Security). We encourage you to transition to [Replacement Product] prior to the retirement date to experience the new capabilities of [Replacement Product] including [insert 1-3 new benefits available in the replacement product].   
    
From now to [Retirement Date] you can continue to use [Feature/Service/Product Name] without disruption. On [Retirement Date] (Insert expected customer impact such as data loss, workload breakage, can no longer scale, etc.). Resources to aid in your migration can be found below.  

[Recommended/Required] (select one) Action    

To avoid service disruptions, please follow our instructions to migrate (hyperlink migration instructions here must be a aka.ms link) to [Replacement product] by [Retirement Date].  

[Add migration instructions and other recommended/required action here]. 

Help and support  

If you have questions, get answers from community experts in  [Microsoft Q&A](https://docs.microsoft.com/answers/topics/25346/azure-kubernetes-service.html) or AKS GitHub [ADD LINK TO GITHUB ISSUE]. If you have a support plan and you need technical help, create a [support request](https://ms.portal.azure.com/#create/Microsoft.Support/Parameters/%7B%0D%0A%09%22subId%22%3A+%22%22%2C%0D%0A%09%22pesId%22%3A+%225a3a423f-8667-9095-1770-0a554a934512%22%2C%0D%0A%09%22supportTopicId%22%3A+%2291f57f19-e9bb-a65c-ecbe-1faf664237e5%22%2C%0D%0A).   

Learn more about service retirements that may impact your resources in the Azure Retirement Workbook. Please note that retirements may not be visible in the workbook for up to two weeks after being announced.    

----- END OF TEMPLATE 

CAUTION:  
- **Do not publish your Github issue until you have retirement plan approval and retirement dates are finalized.** 
- Make sure to include the “Announcement” tag 
- Make sure to add to the AKS public Roadmap in the “Retirements” 

## Email Notification (Azure Comms) Template
_Guidance: Establish a query to identify which subscriptions should get the retirement notifications. Update email template for your retirement._ 

Create your Email draft in CPEX sharepoint: 
- Access [CPEX Sharepoint](https://microsoft.sharepoint.com/:f:/t/azureretirements/ErqhgB-B6YBFtTld9Hgrd2IBNkT5WIw0LFj_UTjcjeburA?e=6Ucy75) 
- Duplicate the “Blank Email Request Template” 
- Update your copy of the template to include details about your retirement 
- Add your email template to the “AKS emails” folder. Feel free to use existing emails as an example. 
- Once completed, add email draft below for review 

Email Notification Draft: <ADD LINK HERE> 

## Marketing disclosure 
_Guidance: Describe your proposed solution via the Announcement/Press Release for it._
 
<Retirement>: <RELEASE> (<owner>)   

Description:  
[Feature/Service/Product Name w/ link to AKS documentation] will be retired on DAY MONTH YEAR [Retirement Date], please transition to [Replacement Product] by that date.    

(Insert reasoning for retirement – New Features, Improvement Performance, Security). We encourage you to transition to [Replacement Product] prior to the retirement date to experience the new capabilities of [Replacement Product] including [insert 1-3 new benefits available in the replacement product].   
    
From now to [Retirement Date] you can continue to use [Feature/Service/Product Name] without disruption. On [Retirement Date] (Insert expected customer impact such as data loss, workload breakage, can no longer scale, etc.). 

[RECOMMENDED/REQUIRED] Action:  

Customers can [Reduce impact, prepare for retirement, etc.] by [Action]. 

Help and support  

If you have questions, get answers from community experts in  [Microsoft Q&A](https://docs.microsoft.com/answers/topics/25346/azure-kubernetes-service.html) or AKS GitHub [ADD LINK TO GITHUB ISSUE]. If you have a support plan and you need technical help, create a [support request](https://ms.portal.azure.com/#create/Microsoft.Support/Parameters/%7B%0D%0A%09%22subId%22%3A+%22%22%2C%0D%0A%09%22pesId%22%3A+%225a3a423f-8667-9095-1770-0a554a934512%22%2C%0D%0A%09%22supportTopicId%22%3A+%2291f57f19-e9bb-a65c-ecbe-1faf664237e5%22%2C%0D%0A).    

To learn more, visit: <<aka.ms LINK>>  

------------  
FAQ:  
What are we announcing?  
What can customers do now that they couldn’t do before?   
What are the pricing and/or licensing implications, if any, for this announcement?   
What are the CTAs for the field?  
Where can we learn more?  
-----------------  
----- END OF TEMPLATE 

# Definition of Success 
_Guidance: Identify the business, customer, and technology outcomes you expect to achieve as a result of announcing this retirement. Particularly important to include is expected migration outcomes and at what point in retirement migration is removal of the retired feature acceptable._

Define the measures you will use to gauge progress. 

Ongoing iteration on the outcomes, and how to measure them, will be critical to success.

Consider leveraging experiments to enable data-driven decisions.  

| No. | Outcome | Measure | Target | Priority  |
|-----|---------|---------|---------|--------|
| 1   |  |  |  |   |
| 2   |  |  |  |   |

## Retirement Landing
After announcing the retirement, you should track feature usage to make sure that customers are migrating to the replacement product. If needed, you may need to send out additional communications or reach out to customers with high usage to aid in their migration. The Azure Comms team will reach out to you to send out reminders at intervals such as 1 year, 6 months, and 3 months until the retirement date.

After the retirement date, there may still be customers using the feature. You should create a feature landing report for the retirement on the retirement date. Retirements can be considered landed when feature usage is at or near 0 and the feature has been removed from AKS code, tests, documentation, etc.

#  Appendix 
_Guidance: Extended information, diagrams, additional queries, and examples_