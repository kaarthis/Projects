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
- To understand if a CPEX retirement is needed for your feature retirement, see AKS Retirement Scenarios and Requirements. 
- The official CPEX retirement process can be found at [aka.ms/cpexretirements](https://aka.ms/cpexretirements). 
```

# Overview 

## Retirement Summary  
_Guidance: Update the outline for your retiring feature. This will be the base for your published content in your email comms, release notes, and Github issue._ 

[Feature/Service/Product Name w/ link to AKS documentation] will be retired on DAY MONTH YEAR [Retirement Date], please transition to [Replacement Product] by that date.    

(Insert reasoning for retirement – New Features, Improvement Performance, Security). We encourage you to transition to [Replacement Product] prior to the retirement date to experience the new capabilities of [Replacement Product] including [insert 1-3 new benefits available in the replacement product].   
    
From now to [Retirement Date] you can continue to use [Feature/Service/Product Name] without disruption. On [Retirement Date] (Insert expected customer impact such as data loss, workload breakage, can no longer scale, etc.). 

## Retirement Justification 
_Guidance: Provide justification for retiring this feature. If an exception to the 3 year timeline is required, provide justification here._ 

Retirement Justification: (Insert reasoning for retirement – New Features, Improvement Performance, Security) 

3 year retirement exception justification: (If needed, describe why we cannot wait 3 years to retire. This justification will need to be brought to AKS PM CVP for approval.) 

## Migration Plan/Customer Action Required 
_Guidance: Provide information on how a customer can migrate to the recommended alternative. And is there any other action customers need to perform._

The below migration is [REQUIRED/RECOMMENDED] (select one). 

Migration Plan: Customers can transition to [Replacement Product] by [Migration Steps].  

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

## Release Notes Template 
_Guidance: Provide example release notes that you will publish regarding this retirement._

[Feature/Service/Product Name w/ link to AKS documentation] will be retired on DAY MONTH YEAR [Retirement Date], please transition to [Replacement Product] by that date. For more information about this retirement, see [aka.ms/aks/feature-name-retirement]. 

-----END OF TEMPLATE 

TIP: The above aka.ms link should link to your github issue. Do not create a Github issue until you have retirement plan approval and the retirement dates are finalized. 

## Github Issue Template
_Guidance: This content will be used in your github issue on AKS Github. It should match your email content._

[Feature/Service/Product Name w/ link to AKS documentation] will be retired on DAY MONTH YEAR [Retirement Date], please transition to [Replacement Product] by that date.  

(Insert reasoning for retirement – New Features, Improvement Performance, Security). We encourage you to transition to [Replacement Product] prior to the retirement date to experience the new capabilities of [Replacement Product] including [insert 1-3 new benefits available in the replacement product].   
    
From now to [Retirement Date] you can continue to use [Feature/Service/Product Name] without disruption. On [Retirement Date] (Insert expected customer impact such as data loss, workload breakage, can no longer scale, etc.). Resources to aid in your migration can be found below.  

[Recommended/Required] (select one) Action    

To avoid service disruptions, please follow our instructions to migrate (hyperlink migration instructions here must be a aka.ms link) to [Replacement product] by [Retirement Date].  

[Add migration instructions and other recommended/required action here]. 

Help and support  

If you have questions, get answers from community experts in  Microsoft Q&A or AKS GitHub. If you have a support plan and you need technical help, create a support request.   

Learn more about service retirements that may impact your resources in the Azure Retirement Workbook. Please note that retirements may not be visible in the workbook for up to two weeks after being announced.    

----- END OF TEMPLATE 

TIPS:  
- Do not publish your Github issue until you have retirement plan approval and retirement dates are finalized. 
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

If you have questions, get answers from community experts in  Microsoft Q&A or AKS GitHub<Update to github issue specific to your retirement>. If you have a support plan and you need technical help, create a support request.   

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

#  Appendix 
_Guidance: Extended information, diagrams, additional queries, and examples_