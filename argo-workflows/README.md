# Argo Workflows for Cloud Native Automation

NOTE: This is very much in experimental phase.

[Argo Worflows](https://argoproj.github.io/argo-workflows) is a container-native pipeline automation tool.  We are leveraging it to perform tasks that you would normally need to script locally.

## Prerequisites

In order to automate the install of Argo Workflows, we will use ArgoCD.  

```
../argocd/install-argocd.sh
```

View the README.md file in the argocd directory for details.

## Installing Argo Workflows

Install Argo Workflows via ArgoCD with the following command:

```
kubectl apply -f deploy/argo-workflows.yaml
```

## Using Argo Workflows

Argo Workflows can be used to automate processes that would usually rely on scripting.  We can use it to run container-native pipelines.  Following is an example of automating the Gloo Mesh Lab2 to deploy and register Gloo Mesh on OpenShift.

```
k apply -f gloo-mesh/lab2/openshift/lab2-ocp-workflow.yaml
```