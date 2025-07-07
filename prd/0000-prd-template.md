---
title: template
wiki: ""
pm-owners: []
feature-leads: []
authors: []
stakeholders: []
approved-by: [] 
---

# Overview 

## Problem Statement / Motivation  

Guidance (when submitting the PRD, please remove this guidance section as it only meant to help you fill out the PRD):
* State the problem or challenge in a way that ties back to the target user. What is their goal? Why does this matter to them? Make the problem real & relevant. 
* Additionally, provide at the beginning a 1-2 sentence summary in the style:

> Before <feature>, AKS customers had to <pain point> to <achieve goal>. 
> Now, AKS customers can <feature steps> to <achieve original goal>." 

## Goals/Non-Goals

### Functional Goals

Guidance (when submitting the PRD, please remove this guidance section as it only meant to help you fill out the PRD):
* What are the key outcomes we want to achieve?
* What are the key user journeys we want to enable?
* What is in scope?

### Non-Functional Goals

Guidance (when submitting the PRD, please remove this guidance section as it only meant to help you fill out the PRD):
* What are the performance, security, and reliability goals?
* What are the compliance goals?
* What are the telemetry and monitoring requirements?
* What are the supportability goals?

### Non-Goals

Guidance (when submitting the PRD, please remove this guidance section as it only meant to help you fill out the PRD):
* What is out of scope for this feature? What will be addressed in a future release?
* What are the limitations or constraints that we will not address in this feature?

## Narrative/Personas

Guidance (when submitting the PRD, please remove this guidance section as it only meant to help you fill out the PRD. The table should be retained and filled out with relevant personas):
* For each persona identified, enumerate the permissions (found under here - https://learn.microsoft.com/en-us/azure/role-based-access-control/resource-provider-operations) this persona requires to complete the user journeys.
* Define user journeys for each persona, what outcomes they are trying to achieve, and how they will measure success.
* Avoid implementation details that may restrict solution choices.

| Persona | Required permissions | User Journey and Success Criteria |
|---------|----------------------|-----------------------------------|
| Example: Cluster operator | Microsoft.ContainerService/managedClusters/* | As a cluster operator, I want to be able to create and manage AKS clusters with Entra authentication by default. I should be able to bootstrap my cluster with necessary permissions for the other developer personas to use my cluster. I should be able to restrict all developers on the cluster to only use Entra authentication and prohibit other authentication methods |
| Example: Developer | Microsoft.ContainerService/managedClusters/read, Microsoft.ContainerService/managedClusters/listClusterUserCredentials/action | As a developer, I want to be able to access the AKS cluster. I should be able to use client tooling to interact with the cluster and deploy applications in a simple and secure way |

## Customers and Business Impact 

Guidance (when submitting the PRD, please remove this guidance section as it only meant to help you fill out the PRD):
* Provide customer data or insights with respects to the Problem Statement.
* Provide links to Kusto queries, customer feedback/interviews, support tickets, or other data that supports the problem statement.
* Provide the business impact and OKR alignment.

## Existing Solutions or Expectations 

Guidance (when submitting the PRD, please remove this guidance section as it only meant to help you fill out the PRD):
* List the various ways in which a user may currently tackle this problem/challenge. 
* With what expectations will customers approach our solution (competitors or current behaviors)?
* What are the gaps in the current solutions that we are trying to address?

## What will the announcement look like?

**Announcing <foo feature> for Azure Kubernetes Service (AKS)**

We are thrilled to introduce [Feature Name], a new feature designed to [briefly describe the purpose and benefit of the feature]. With [Feature Name], you can now [briefly describe the main functionality]. 

**Addressing Key Challenges**

[Describe the common challenges or pain points that the feature aims to address. Explain why these challenges are significant and how the feature will help overcome them.] 

**Functionality and Usage**

[Provide a detailed description of the feature's functionality. Explain how users can utilize the feature and what benefits it offers.] 

**Availability**

[Provide information about the availability of the feature. Mention any version requirements, rollout plans, or timelines.] 

For more information, review the detailed documentation on how to make the most of this exciting new feature! 

## Proposal 

Guidance (when submitting the PRD, please remove this guidance section as it only meant to help you fill out the PRD):
* Describe the possible options for addressing the problem statement.
* For each option, describe the pros and cons.
* Identify the recommended option and why it is the best choice.
* Are there any breaking changes resulting from the proposed solution? If so, please note that here.
* Capture the go to market for the feature/offering and how it will be positioned.
* Is there any changes to the pricing model? If pricing plans aren't finalized and will be finalized later, please note that here.

## User Experience 

Guidance (when submitting the PRD, please remove this guidance section as it only meant to help you fill out the PRD):
* For each user journey identified in the Personas section, describe the user experience.

### API
Guidance (when submitting the PRD, please remove this guidance section as it only meant to help you fill out the PRD):
* https://github.com/Azure/azure-rest-api-specs/tree/main/specification/containerservice/resource-manager/Microsoft.ContainerService/aks contains the current API specifications for AKS.
* In this section, describe only the delta changes to the API that are required to deliver the user experience.

### CLI Experience

Guidance (when submitting the PRD, please remove this guidance section as it only meant to help you fill out the PRD):
* https://learn.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest contains the current CLI commands for AKS.
* In this section, describe only the delta changes to the CLI that are required to deliver the user experience.

### Portal Experience

Guidance (when submitting the PRD, please remove this guidance section as it only meant to help you fill out the PRD):
* Include links to Figma designs or screenshots of the portal experience.

### Policy Experience
Guidance (when submitting the PRD, please remove this guidance section as it only meant to help you fill out the PRD):
* Describe any built-in [policy definitions](https://learn.microsoft.com/azure/governance/policy/concepts/definition-structure-basics) that will be required to deliver the user experience.
* Describe any [policy initiatives](https://learn.microsoft.com/en-us/azure/governance/policy/concepts/initiative-definition-structure) that will be required to deliver the user experience.

# Definition of Success 

## Expected Impact: Business, Customer, and Technology Outcomes, Experiments + Measures 

Guidance: Identify the business, customer, and technology outcomes you expect to achieve as a result of delivering on this scenario.

Define the measures you will use to gauge progress. 

Ongoing iteration on the outcomes, and how to measure them, will be critical to success.

Consider leveraging experiments to enable data-driven decisions.  

| No. | Outcome | Measure | Target | Priority  |
|-----|---------|---------|---------|--------|
| 1   |  |  |  |   |
| 2   |  |  |  |   |

# Requirements 

## Functional Requirements 

Guidance: What feature functionality is required to deliver the outcomes listed above? 

| No. | Requirement | Priority  |
|-----|---------|---------|
| 1   |  |  |
| 2   |  |  |

## Test Requirements 

Guidance: What testing functionality is required to deliver the outcomes listed above? 

| No. | Requirement | Priority  |
|-----|---------|---------|
| 1   |  |  |
| 2   |  |  |

# Dependencies and risks 

Guidance: At a high level, what dependencies from other teams / orgs are required?

What are the risks such as slip from these dependencies? 

| No. | Requirement or Deliverable | Giver Team / Contact |
|-----|---------|---------|
| 1   |  |  |
| 2   |  |  |

# Compete 

Guidance: What are the related current solutions and behavior we see from our competitors?

## GKE 

## EKS 
