#!/bin/bash

license_key=$1
cluster1_context="cluster1"
cluster2_context="cluster2"
mgmt_context="mgmt"
gloo_mesh_overlay="1-2-16"
gloo_mesh_version="1.2.16"
istio_overlay="1-11-4"

# check to see if defined contexts exist
if [[ $(kubectl config get-contexts | grep ${mgmt_context}) == "" ]] || [[ $(kubectl config get-contexts | grep ${cluster1_context}) == "" ]] || [[ $(kubectl config get-contexts | grep ${cluster2_context}) == "" ]]; then
  echo "Check Failed: Either mgmt, cluster1, and cluster2 contexts do not exist. Please check to see if you have three clusters available"
  echo "Run 'kubectl config get-contexts' to see currently available contexts. If the clusters are available, please make sure that they are named correctly. Default is mgmt, cluster1, and cluster2"
  exit 1;
fi

# check to see if license key variable was passed through, if not prompt for key
if [[ ${license_key} == "" ]]
  then
    # provide license key
    echo "Please provide your Gloo Mesh Enterprise License Key:"
    read license_key
fi

# sed command to replace license key  
sed -i -e "s/<INSERT_LICENSE_KEY_HERE>/${license_key}/g" gloo-mesh/argo/${gloo_mesh_overlay}/gloo-mesh-ee-helm-openshift.yaml

# install argocd on mgmt, ${cluster1_context}, and ${cluster2_context}
cd argocd
./install-argocd.sh default ${mgmt_context}
./install-argocd.sh default ${cluster1_context}
#./install-argocd.sh default ${cluster2_context}

# wait for argo cluster rollout
../tools/wait-for-rollout.sh deployment argocd-server argocd 10 ${mgmt_context}
../tools/wait-for-rollout.sh deployment argocd-server argocd 10 ${cluster1_context}
#../tools/wait-for-rollout.sh deployment argocd-server argocd 10 ${cluster2_context}

# install gloo-mesh on mgmt
cd ../gloo-mesh/
kubectl apply -f argo/${gloo_mesh_overlay}/gloo-mesh-ee-helm-openshift.yaml --context ${mgmt_context}

../tools/wait-for-rollout.sh deployment enterprise-networking gloo-mesh 10 ${mgmt_context}

# install istio on ${cluster1_context} and ${cluster2_context}
cd ../istio
kubectl apply -f argo/deploy/${istio_overlay}/operator/istio-operator-${istio_overlay}.yaml --context ${cluster1_context}
#kubectl apply -f argo/deploy/${istio_overlay}/operator/istio-operator-${istio_overlay}.yaml --context ${cluster2_context}

../tools/wait-for-rollout.sh deployment istio-operator istio-operator 10 ${cluster1_context}
#../tools/wait-for-rollout.sh deployment istio-operator istio-operator 10 ${cluster2_context}

kubectl apply -f argo/deploy/${istio_overlay}/gm-istio-profiles/gm-istio-openshift-cluster1.yaml --context ${cluster1_context}
#kubectl apply -f argo/deploy/${istio_overlay}/gm-istio-profiles/gm-istio-openshift-cluster2.yaml --context ${cluster2_context}

../tools/wait-for-rollout.sh deployment istiod istio-system 10 ${cluster1_context}
#../tools/wait-for-rollout.sh deployment istiod istio-system 10 ${cluster2_context}

# set strict mtls
#kubectl apply -f argo/deploy/mtls/strict-mtls.yaml --context ${cluster1_context}
#kubectl apply -f argo/deploy/mtls/strict-mtls.yaml --context ${cluster2_context}

# register clusters to gloo mesh
cd ../gloo-mesh/
#./scripts/meshctl-register.sh ${mgmt_context} ${cluster1_context} ${meshctl_version}
#./scripts/meshctl-register.sh ${mgmt_context} ${cluster2_context} ${meshctl_version}
#./scripts/meshctl-register-helm-argocd.sh ${mgmt_context} ${cluster1_context} ${cluster2_context} ${gloo_mesh_version}
./scripts/meshctl-register-helm-argocd-1-cluster-hostname.sh ${mgmt_context} ${cluster1_context} ${gloo_mesh_version}

