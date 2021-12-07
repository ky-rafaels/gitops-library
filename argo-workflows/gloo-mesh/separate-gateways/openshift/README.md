This scenario takes the typical Lab 3 Istio installation but creates two individual IstioOperator installations.

The first installs istiod and uses profile `openshift`.  
The second installs the ingress-gateway in the istio-gateways namespace.  Optionally, it will install a secondary gateway.