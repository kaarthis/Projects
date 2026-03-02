# Managed Gateway API Installation

**Author(s)**:  jkatariya

**PRD**: [link](https://microsoft.sharepoint.com/:w:/r/teams/azurecontainercompute/Shared%20Documents/AKS/AKS%20PRDs%20-%20Product%20Requirement%20Docs/Developer%20Experience/Automatic/App%20Routing/Gateway%20API%20for%20AKS.docx?d=wb436bf27ef1c4f35b9f302c982b0bfdd&csf=1&web=1&e=mcrpSc)

**Design doc:** [link](https://microsoft.sharepoint.com/:w:/r/teams/azurecontainercompute/Shared%20Documents/AKS/AKS%20Traffic/Design%20Docs/Traffic%20Management/Gateway%20Addon%20Design%20Doc.docx?d=w29f9fe96407d4d05b1cae6094117772c&csf=1&web=1&e=WkjcSF)

**Preview API Proposal for the Managed Gateway API Installation:** [link](https://msazure.visualstudio.com/CloudNativeCompute/_wiki/wikis/CloudNativeCompute.wiki/767757/Gateway-Managed-Installation)

## Required Pre-Requisites

- [x] This API is a preview API, OR it is a GA API. For GA APIs, all [LRB GA criteria](https://msazure.visualstudio.com/CloudNativeCompute/_wiki/wikis/CloudNativeCompute.wiki/388576/LRB-Checklist-Template?anchor=ga-checklist)
  items that can be done prior to GA-ing the API are done. This includes quality, QOS, scalability, buildout (including sovereign), etc - see the LRB list for the full set.

## Brief description of why this change is needed

The Managed Gateway API Installation deploys Kubernetes Gateway API CRDs on users' clusters, providing them with a fully supported, Gateway API-based traffic management experience. Currently, users need to manually install Gateway API CRDs to route traffic via the Kubernetes Gateway API on AKS. This API change allows users to opt into the managed installation for Standard channel Gateway API CRDs.

## REST API proposal

```diff
/**
 * Ingress profile for the container service cluster.
 */
model ManagedClusterIngressProfile {
  /**
   * App Routing settings for the ingress profile. You can find an overview and onboarding guide for this feature at https://learn.microsoft.com/en-us/azure/aks/app-routing?tabs=default%2Cdeploy-app-default.
   */
  webAppRouting?: ManagedClusterIngressProfileWebAppRouting;

  /**
   * Settings for the managed Gateway API installation
   */
  #suppress "@azure-tools/typespec-azure-core/casing-style" "FIXME: Update justification, follow aka.ms/tsp/conversion-fix for details"
+ @added(Versions.v2026_02_01)
  gatewayAPI?: ManagedClusterIngressProfileGatewayConfiguration;

  /**
   * Settings for the managed Application Load Balancer installation
   */
  @added(Versions.v2026_01_02_preview)
  applicationLoadBalancer?: ManagedClusterIngressProfileApplicationLoadBalancer;
}

/** Configuration for managed Gateway API CRDs. See https://aka.ms/k8s-gateway-api for more details.
+ @added(Versions.v2026_02_01)
model ManagedClusterIngressProfileGatewayConfiguration {
  /**
   * Configuration for the managed Gateway API installation. If not specified, the default is 'Disabled'. See https://aka.ms/k8s-gateway-api for more details.
   */
  installation?: ManagedGatewayType;
}
```

## CLI Proposal (optional)
Example: Enable the feature to use with AGC and the app routing add-on

```bash
az aks create -n contoso -g contoso-aks --enable-app-routing --enable-gateway-api
```

Example: Enable the feature to use with Azure Service Mesh 

```bash
az aks create -n contoso -g contoso-aks --enable-asm --enable-gateway-api
```

Example: Enable the feature to use with App Routing Istio

```bash
az aks create --name contoso-aks --resource-group contoso-rg --enable-gateway-api --enable-app-routing-istio
```

Example: Enable the feature to use on an existing cluster

```bash
az aks update --name contoso-aks --resource-group contoso-rg --enable-gateway-api
```
