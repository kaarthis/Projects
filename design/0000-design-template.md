Please follow the design process [here](https://msazure.visualstudio.com/CloudNativeCompute/_wiki/wikis/CloudNativeCompute.wiki/18201/AKS-ARO-Design-Review-Process).

# Title
**Author**:
**Created**:
**Last Modified**:
**Status**: Draft, Discussion, Approved
**PRD**: <link>
**Stakeholders:**
**Approvers**: 

- [ ] Qi Ke (optional)
- [ ] Your manager
- [ ] 1 PM
- [ ] 1 AKS Eng Lead out of your immediate team/SIG
- [ ] 1 AKS Eng Lead who is an immediate stakeholder to your feature (optional)
- [ ] Listed Stakeholder Quorum
- [ ] _If any changes need to make on underlay, please get @<Jason Wilder> 's approval as well_
- [ ] _If any changes to public AKS RP API, please follow the [API review process](https://msazure.visualstudio.com/CloudNativeCompute/_wiki/wikis/CloudNativeCompute.wiki/232501/API-Review-Process?anchor=process) and get approval from the required API reviewers. Ping [AKS API Channel](https://teams.microsoft.com/l/channel/19%3a106ed06b2a3745b1a7ee5c573ab098c6%40thread.skype/AKS%2520API%2520channel?groupId=e121dbfd-0ec1-40ea-8af5-26075f6a731b&tenantId=72f988bf-86f1-41af-91ab-2d7cd011db47) for async review._
 
## Feature PRD
 
Link to the **APPROVED** Product Requirement Doc (PRD) and/or a short description of the feature.
 
## Requirements
 
Include functional and non-functional requirements for the design. Functional requirements cover the specific behavior of a system: feature x should do y. Non-functional requirements specify the characteristics of the system: feature x should use y amount of resources or be available n% of the time.
 
Including a few user stories may help round out the shape of the requirements, and would be good to include.

If this work requires integration with other systems/products, please work with the partner teams to collect below metrics data from the dependency product:
  - [ ] Usage numbers and dashboard from production
  - [ ] QoS / reliability numbers and dashboard from production
  - [ ] Performance numbers and dashboard from production
  - [ ] Scalability numbers and dashboard from production (prefer having tests with expected concurrency)

If the system is new and missing sufficient production numbers from customer traffic, please advice partner teams to develop runners to generate traffic continuously on production. And run perf, scale tests periodically, such as daily or if too expensive, at least once a week to ensure no regression from release to release.

The reason we are asking for these numbers is because AKS is a complex system. We need every component in the system to be sufficiently tested so that: 1) catch issues earlier, without waiting for integration into AKS; 2) repro in a cheaper way; 3) easier to root cause. Think about NASA, they can't keep launching rockets to verify if sealant is working.

## Metrics for Success
 
Key metrics by which this design/feature/bug can be observed. Areas to consider, deployment progress, rollout progress, operational capacity/capability.
 
* For new features, how do we measure that the feature is working as intended?
* For bug fixes, how do we measure that the bug fix is successful?

## Solutions considered
 
### Option A
For each solution, include a brief overview of the proposed solution, provide context, pros and cons. For pros and cons, best is to provide reference doc or numbers collected through experiments unless it's common sense.

### Option B

> Always consider at least two options and provide evaluations

### Decision
Hope the sections above are self explaining enough why the decision is made, otherwise, give more explanation here.

It's OK to not make a decision at early stage of design doc. Soliciting early feedback is encouraged. If decision is not made, skip all the sections below and proceed after decision is made.

If a decision can not be made, list out what additional investigation or experiments need to perform to help make the decisions.
 
## Design / Build
 
How do we want to approach building this feature/bug fix. Is there any refactoring that needs to happen before the feature can be implemented.
 
## Milestones / Phases
 
Breaking down the work ahead of us, how do we want to arrive at our ultimate goal? Priority should be incremental progress that is testable/observable along the way. How can we break up the work to achieve small, tractable results while working to solve the larger problem?

### Version Matrix K8S or any OSS components involved

| TIME |  Phase | Kubernetes Version | CoreDNS version |
|------|--------|--------------------|-----------------|
| time1| Preview| e.g. >=1.17        |
| time2| GA     | e.g. >=1.20(or the same as above)|

## Testing (careful - top lesson learned from postmortems!)

* What unit, functional, system/integration, or backward-compatibility tests need to be included to ensure feature quality?
* What tests should be run as part of an e2e suite?
* What are the negative test cases to run for unsupported scenarios?
* What type of failures should we test? Think CHAOS testing.
 
## Security and privacy
 
Are there issues specific to this feature/bugfix that have security implications for our infra, customer infra, or secrets management. We do not need to solve security design in this document, but we should note any potential areas for further focus.
 
## Scale
 
Are scaling requirements generally understood? Do we have a general understanding of the load required, number of agents, connections, read/write load, etc? We do not need to solve scale problems in this document but we should note any potential areas for further focus.

## QoS/Latency impact

* What is your top-level SLI for this feature?
* What existing metrics should oncall look into that can be impacted by this feature? 
* What new metrics will be added to reflect additional qos/latency changes?
* What metrics will be added to track number of retries and total duration till success or failure if there is retry logic in the code.
* What scenarios of this new feature could lower AKS QoS?
* Will this new feature increase cluster creation latency?
* Will this new feature introduce new images/binary that should be baked in AKS VHD?

## Monitor
 
Once this feature is deployed what do we need to watch to ensure that the feature is functioning appropriately. What, if any,  operational alerts and thresholds need to be established for smooth operations? 

## COGS Impact

Is there a COGS impact due to this feature? Is this increasing our resource consumption? If so, by how much? Did you consider the COGS impact at scale? Can someone abuse our resources?
 
## Public REST API changes

Follow the [API review process](https://msazure.visualstudio.com/CloudNativeCompute/_wiki/wikis/CloudNativeCompute.wiki/232501/API-Review-Process?anchor=process). Finalize that API design before design as it may force you to change your approach. Encourage PRD to take the lead in api design if it is not small. 

## Deploy
 
How will this feature/bug be deployed to customers?
 
* Deployed behind feature flag
* Opt-in by customer/backend system
* Rolled out in canary
* Progressive rollout: 10%, 15%, 30%, 50%, 75%, 100%
* Are there specific risks associated with shipping this feature or fix:
  * Backwards compatibility issues
  * Changing functions of scale
* Will this feature require any new resource added that might require 0-touch work automation work?
 
## Supportability and TSGs
 
How will this new capability be supported in production? What supportability tooling should be included? Areas might include Geneva Actions, emitting events, emitting telemetry, TSGs, AppLens detectors, Resource Health events, new views in ASI.
 
### Impacted/Affected Customers
 
List of customers, ICMs, CSS cases, or prospects interested in the feature and/or fix.

## Dependency services

If additional Azure service is required for this feature, please add to the [Feature Dependencies](https://msazure.visualstudio.com/CloudNativeCompute/_wiki/wikis/CloudNativeCompute.wiki/15033/Dependencies?anchor=features-dependencies) list

## Go over [GA checklist](https://msazure.visualstudio.com/CloudNativeCompute/_wiki/wikis/CloudNativeCompute.wiki/19281/AKS-Preview-and-GA-Feature-Checklists) for any additional considerations
