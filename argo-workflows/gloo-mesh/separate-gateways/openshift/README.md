# Installing Istio in OpenShift with separate gateways and control-plane
This scenario takes the typical Lab 3 Istio installation but creates two individual IstioOperator installations.

The first installs istiod and uses profile `openshift`.  
The second installs the ingress-gateway in the istio-gateways namespace.  Optionally, it will install a secondary gateway.

To install this via argoCD, follow these steps allowing time for argo to sync between each step.

Setup security
```
oc --context ${CLUSTER1} adm policy add-scc-to-group anyuid system:serviceaccounts:istio-system
oc --context ${CLUSTER1} adm policy add-scc-to-group anyuid system:serviceaccounts:istio-operator
oc --context ${CLUSTER1} adm policy add-scc-to-group anyuid system:serviceaccounts:istio-gateways
```
First, deploy the operator.
```
kubectl apply -f cluster1/istio-operator.yaml
```
Next, deploy the control plane.
```
kubectl apply -f cluster1/istio.yaml
```
Finally, deploy the gateways.
```
kubectl apply -f cluster1/istio-gateways.yaml
```

Finally, expose the ingressgateway
```
oc --context ${CLUSTER1} -n istio-gateways expose svc/istio-ingressgateway --port=http2
```