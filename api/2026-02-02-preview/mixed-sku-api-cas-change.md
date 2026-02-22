# Mixed SKU Agent Pools API change for CAS support

**Author(s)**:  @reneeli_microsoft, @wenxuanwang_microsoft

**PRD**:        [PRD](https://microsoft.sharepoint.com/:w:/r/teams/azurecontainercompute/_layouts/15/Doc.aspx?sourcedoc=%7BB32EA35E-7625-4F4B-B6FC-6F7AEBD39F23%7D&file=Mixed%20SKU%20Nodepool.docx&action=default&mobileredirect=true&ovuser=72f988bf-86f1-41af-91ab-2d7cd011db47%2Cwenjungao%40microsoft.com&clickparams=eyJBcHBOYW1lIjoiVGVhbXMtRGVza3RvcCIsIkFwcFZlcnNpb24iOiIyOC8yMzA5MDExMjIyOSIsIkhhc0ZlZGVyYXRlZFVzZXIiOmZhbHNlfQ%3D%3D)

**Design doc:** N/A

## Required Pre-Requisites

- [x] This API is a preview API, OR it is a GA API. For GA APIs, all [LRB GA criteria](https://msazure.visualstudio.com/CloudNativeCompute/_wiki/wikis/CloudNativeCompute.wiki/388576/LRB-Checklist-Template?anchor=ga-checklist)
  items that can be done prior to GA-ing the API are done. This includes quality, QOS, scalability, buildout (including sovereign), etc - see the LRB list for the full set.

## Brief description of why this change is needed

The initial decision for preview to not support mixed SKU autoscaling was meant to maintain a distinction between VM node pools and Node Auto Provisioning (NAP), which also provides mixed SKU autoscaling. The decision to add mixed SKU autoscaling to VM node pools is to give customers more flexibility. VM Node Pools with mixed SKU autoscaling can offer more capacity resilience for users who cannot fully migrate to NAP.

## REST API proposal

**Breaking change note (preview API):**

- **What changed:** The `ScaleProfile.autoscale` property changes from a single object (`autoscale?: AutoScaleProfile`) to an array (`autoscale?: AutoScaleProfile[]`) to support multiple autoscale profiles.
- **Impact:** This is a breaking wire-format change. Previous API versions that use the single-object shape will not be carried forward; the newer API version only accepts and returns the array shape.
- **Required client action:** Clients must update their request payloads by wrapping the existing single `autoscale` object in an array (e.g., `{ "autoscale": { ... } }` → `{ "autoscale": [ { ... } ] }`), or regenerate their client from the latest SDK.
- **Response change:** Service responses will also return `autoscale` as an array going forward.

> **Cross-version compatibility note:**
>
> - **Old API → New API:** If a client uses the old API (single-object `autoscale`) to GET/PUT and then switches to the new API (array `autoscale`), the previously configured single item will appear as the 0th element in the array.
> - **New API → Old API:** If a client uses the new API to GET/PUT (potentially with multiple autoscale profiles in the array) and then uses the old API to GET, only the 0th item in the array is returned as the single object. Any additional items (index 1+) are **not shown** and will not be visible through the old API.

```typescript

/**
 * Specifications on how to scale a VirtualMachines agent pool.
 */
model ScaleProfile {
  /**
   * Specifications on how to scale the VirtualMachines agent pool to a fixed size.
   */
  @identifiers(#[])
  manual?: ManualScaleProfile[];

  /**
   * Specifications on how to auto-scale the VirtualMachines agent pool within a predefined size range.
   * Each profile targets a specific VM SKU and is evaluated independently.
   * Scaling decisions across profiles are governed by the cluster autoscaler expander,
   * configurable via `ManagedCluster.properties.autoScalerProfile.expander`.
   */
  @identifiers(#[])
  @added(Versions.v2026_02_02_preview)
  autoscale?: AutoScaleProfile[];
}

```

## CLI Proposal (optional)

Only propose CLI experience change for Auto scale to align with Manual scale experience

### Enable CAS on cluster - this will create the first autoscale profile **Unchanged**
```
az aks create -g <rg> -n <rn> \
    --vm-set-type "VirtualMachines" \
    --node-vm-size "Standard_D4s_v3"
    --min-count 3 \
    --max-count 5 \
    --enable-cluster-autoscaler # agentpool-level
```

### Enable autoscale on existing manual VMS pool 

####_Option 1_: Only works if current manual VMS pool is single SKU, so need to delete all other manual profiles first. **Unchanged** 
```
az aks nodepool update -g <rg> --cluster-name <clusterName> --name <APname> \
    --vm-set-type "VirtualMachines" \
    --node-vm-size "Standard_D4s_v3" \
    --min-count 3 \
    --max-count 5 \
    --enable-cluster-autoscaler   
```

#### _Option 2_: **Convert a mixed‑SKU manual VMS pool directly to a mixed‑SKU auto VMS pool** - All auto profiles will initially use the same min/max counts. Users can later adjust per‑profile min/max values via the `auto-scale update` command.
```
az aks nodepool update -g <rg> --cluster-name <clusterName> --name <APname> \
    --vm-set-type "VirtualMachines" \
    --min-count 3 \
    --max-count 5 \
    --enable-cluster-autoscaler 
```

### Add VMS pool with autoscale enabled with first autoscale profile **Unchanged**
```
az aks nodepool add -g <rg> --cluster-name <clusterName> --name <APname> \
    --vm-set-type "VirtualMachines" \
    --node-vm-size "Standard_D4s_v2" \
    --min-count 3 \
    --max-count 5 \
    --enable-cluster-autoscaler
```

### Update an existing autoscale profile  **Changed** 
```diff
-- az aks nodepool update -g <rg> --cluster-name <clusterName> --name <APname> \ 
++ az aks nodepool auto-scale update -g <rg> --cluster-name <clusterName> --name <APname> \ 
++  --current-node-vm-size "Standard_D2s_v3" \
    --node-vm-size "Standard_D8s_v3" \
    --min-count 2 \
    --max-count 4 \
--  --update-cluster-autoscaler \
```

### Add an autoscale profile **NEW**
```
az aks nodepool auto-scale add -g <rg> --cluster-name <clusterName> --name <APname> \ 
    --node-vm-size "Standard_D2s_v3" \
    --min-count 3 \
    --max-count 5 \
```


### Delete an existing autoscale profile **NEW**
```
az aks nodepool auto-scale delete -g <rg> --cluster-name <clusterName> --name <APname> \ 
    --current-node-vm-size "Standard_D2s_v3" \
```
