# Meshless Istio for Managed Ingress via Gateway API

**Author(s)**: jkatariya

**PRD**: [link](https://microsoft.sharepoint.com/:w:/r/teams/azurecontainercompute/Shared%20Documents/AKS/AKS%20Traffic/Design%20Docs/Service%20Mesh/Istio%20+%20App-Routing%20+%20Gateway%20API/Istio%20Add-On%20Gateway%20API%20Ingress%20with%20App%20Routing.docx?d=w1ce13669d6f14389b6738d4979680073&csf=1&web=1&e=cMcymY)

**Design doc:** [design doc](https://microsoft.sharepoint.com/:w:/r/teams/azurecontainercompute/Shared%20Documents/AKS/AKS%20Traffic/Design%20Docs/Service%20Mesh/Istio%20+%20App-Routing%20+%20Gateway%20API/Istio%20Add-On%20Gateway%20API%20Ingress%20with%20App%20Routing.docx?d=w1ce13669d6f14389b6738d4979680073&csf=1&web=1&e=cMcymY), [API proposal loop doc shared with PMs](https://microsoft.sharepoint.com/:fl:/s/1bf3f1e3-53ce-4976-9d50-244c005f92e4/ES76i_64zt5KlarJzfgb8-cB0uRmFd1FCiYYpfePZy4Yyw?e=Im3u32&nav=cz0lMkZzaXRlcyUyRjFiZjNmMWUzLTUzY2UtNDk3Ni05ZDUwLTI0NGMwMDVmOTJlNCZkPWIlMjFGYS1UTEFOdlEwdWJXQkc2U3Q4UFFjRWF6ZjFxOVNwUHZpVGpHMndfRnFHZ2lxaDlwanBFVHFac05PQTJVbElTJmY9MDFQVFBBR1ZKTzdLRjc1T0dPM1pGSkxLV0paWDRCWDQ3SCZjPSUyRiZhPUxvb3BBcHAmeD0lN0IlMjJ3JTIyJTNBJTIyVDBSVFVIeHRhV055YjNOdlpuUXVjMmhoY21Wd2IybHVkQzVqYjIxOFlpRjJZMVJJTVdka1EwZHJaVEZFTFZsblVucE1PRkZzVkVkeFMyaGhkR2sxU0d0UlJIcFRaa2N6TmpCTUxVSmFaVFoyTFRSbVVrbEhVa2t5VmpaaWNqRnlmREF4UlZwWVRFVlhWelZHVlVRelIwYzNWa2hTUVRKQk5sSkdNekpDVEZjM1N6WSUzRCUyMiUyQyUyMmklMjIlM0ElMjI2MjkzZGRmMy00ZTJmLTQxOGYtOWI0Ni1jZTA1MTE5OWQ1YjUlMjIlN0Q%3D)

**Preview API Proposal for Meshless:** [link](https://msazure.visualstudio.com/CloudNativeCompute/_wiki/wikis/CloudNativeCompute.wiki/855608/Meshless-Istio-for-Gateway-API-Ingress)
## Required Pre-Requisites

- [x] This API is a preview API, OR it is a GA API. For GA APIs, all [LRB GA criteria](https://msazure.visualstudio.com/CloudNativeCompute/_wiki/wikis/CloudNativeCompute.wiki/388576/LRB-Checklist-Template?anchor=ga-checklist)
  items that can be done prior to GA-ing the API are done. This includes quality, QOS, scalability, buildout (including sovereign), etc - see the LRB list for the full set.

## Brief description of why this change is needed
This feature will allow users to deploy a limited Istio control plane that will be used to provide a Gateway API based managed ingress experience. Since this feature will be marketed as a replacement for the existing nginx-based app routing managed ingress experience, we've decided to include enablement for this feature within the `webAppRouting` object in the cluster `ingressProfile`. To allow for other providers to be used/selectively enabled alongside Istio in the future, we've made Gateway configurations its own object within app routing, where other providers like envoy AI gateway can have their own configurations in the future.

One noteworthy point is that this mode cannot be enabled while `serviceMeshProfile.mode` is set to `Istio`, since it becomes impossible to determine if users are attempting to enable a "mesh-ful" Istio control plane or the limited, ingress-only one.

## REST API proposal

```diff
/**
 * Whether to enable Istio as a Gateway API implementation for managed ingress with App Routing.
 */
+ @added(Versions.v2026_02_01)
union GatewayAPIIstioEnabled {
  string,

  /**
   * Enables managed ingress via the Gateway API using a sidecar-less Istio control plane.
   */
  Enabled: "Enabled",

  /**
   * Disables the sidecar-less Istio control plane for managed ingress via the Gateway API.
   */
  Disabled: "Disabled",
}

...

model ManagedClusterIngressProfileWebAppRouting {
  /**
   * Whether to enable the Application Routing add-on.
   */
  enabled?: boolean;

  /**
   * Configurations for Gateway API providers to be used for managed ingress with App Routing. See https://aka.ms/k8s-gateway-api for more information on the Gateway API.
   */
  #suppress "@azure-tools/typespec-azure-core/casing-style" "Property name maintained to align with protos JSON field naming conventions"
+ @added(Versions.v2026_02_01)
  gatewayAPIImplementations?: ManagedClusterWebAppRoutingGatewayAPIImplementations;

...

/** Configurations for Gateway API providers to be used for managed ingress with App Routing. */
#suppress "@azure-tools/typespec-azure-core/casing-style" "Property name maintained to align with protos JSON field naming conventions"
+ @added(Versions.v2026_02_01)
model ManagedClusterWebAppRoutingGatewayAPIImplementations {
  /**
   * Configuration for using a sidecar-less Istio control plane for managed ingress via the Gateway API with App Routing. See https://aka.ms/gateway-on-istio for information on using Istio for ingress via the Gateway API.
   */
  appRoutingIstio?: ManagedClusterAppRoutingIstio;
}

/** Configuration for using a sidecar-less Istio control plane for managed ingress via the Gateway API with App Routing. See https://aka.ms/gateway-on-istio for information on using Istio for ingress via the Gateway API. */
+ @added(Versions.v2026_02_01)
model ManagedClusterAppRoutingIstio {
  /**
   * Whether to enable Istio as a Gateway API implementation for managed ingress with App Routing.
   */
  mode?: GatewayAPIIstioEnabled;
}


```

## CLI Proposal (optional)
The single flag we'll add to az aks create is `--enable-app-routing-istio`, which will be analogous to the existing `--enable-app-routing` flag. `--enable-app-routing-istio` will set app routing to enabled if it isn't already.

Two new subcommands will be added to the `az aks approuting` suite, which is used to update app routing configuration on existing clusters: `az aks approuting gateway istio enable` and `az aks approuting gateway istio disable`.

### Enable GatewayAPIIngressOnly Mode During AKS Cluster Creation
```bash
az aks create \
  --name contoso-aks \
  --resource-group contoso-rg \
  --enable-gateway-api \
  --enable-app-routing-istio
```

### Enablement Fails When Istio Add-On is Enabled
```bash
az aks create \
  --name contoso-aks \
  --resource-group contoso-rg \
  --enable-gateway-api \
  --enable-app-routing-istio \
  --enable-azure-service-mesh

ERROR: App Routing gateway mode with Istio cannot be enabled simultaneously with the Istio Service Mesh add-on. Please either enable the Service Mesh add-on OR Istio mode for app routing.
```

### Enable GatewayAPI Mode on an Existing AKS Cluster
```bash
az aks approuting gateway istio enable \
  --name contoso-aks \
  --resource-group contoso-rg
```
 
### Disable GatewayAPI Mode on an Existing AKS Cluster  
```bash
az aks approuting gateway istio disable \
  --name contoso-aks \
  --resource-group contoso-rg
```
