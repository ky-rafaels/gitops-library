#!/usr/bin/env bash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT 

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

usage() {
    cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] version

This script will automate Lab2 of the Gloo Mesh Workshop for OpenShift.  
This script will assume the standard contexts of mgmt, cluster1 and cluster2.
It will utilize ArgoCD and Argo Workflows to automate the process.

Available options:

-h, --help      Print this help and exit
-v, --verbose   Print script debug info
EOF
    exit
}

cleanup() {
    trap - SIGINT SIGTERM ERR EXIT
    rm tmp-*
}

setup_colors() {
    if [[ -t 2 ]] && [[ -z "${NO_COLOR-}" ]] && [[ "${TERM-}" != "dumb" ]]; then
        NOFORMAT='\033[0m' RED='\033[0;31m' GREEN='\033[0;32m' ORANGE='\033[0;33m' BLUE='\033[0;34m' PURPLE='\033[0;35m' CYAN='\033[0;36m' YELLOW='\033[1;33m'
    else
        NOFORMAT='' RED='' GREEN='' ORANGE='' BLUE='' PURPLE='' CYAN='' YELLOW=''
    fi
}

msg() {
    echo >&2 -e "${1-}"
}

die() {
    local msg=$1
    local code=${2-1} # default exit status 1
    msg "$msg"
    exit "$code"
}

parse_params() {
    # default values of variables set from params
    param=''

    while :; do
        case "${1-}" in 
        -h | --help) usage ;;
        -v | --verbose) set -x ;;
        --no-color) NO_COLOR=1 ;;
        -?*) die "Unknown option: $1" ;;
        *) break ;;
        esac
        shift
    done

    args=("$@")

    # check required params and arguments
    #[[ ${#args[@]} -eq 0 ]] && die "Missing required argument - version"
    [[ -z "${GLOO_MESH_LICENSE_KEY}" ]] && die "Missing env var GLOO_MESH_LICENSE_KEY"

    return 0
}

parse_params "$@"
setup_colors

# Script logic
echo "Setup namespaces"
echo ""
kubectl --context ${CLUSTER1} create namespace gloo-mesh-addons
kubectl --context ${CLUSTER1} label namespace gloo-mesh-addons istio-injection=enabled
kubectl --context ${CLUSTER2} create namespace gloo-mesh-addons
kubectl --context ${CLUSTER2} label namespace gloo-mesh-addons istio-injection=enabled
oc --context ${CLUSTER1} adm policy add-scc-to-group anyuid system:serviceaccounts:gloo-mesh-addons

cat <<EOF | oc --context ${CLUSTER1} -n gloo-mesh-addons create -f -
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: istio-cni
EOF

oc --context ${CLUSTER2} adm policy add-scc-to-group anyuid system:serviceaccounts:gloo-mesh-addons

cat <<EOF | oc --context ${CLUSTER2} -n gloo-mesh-addons create -f -
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: istio-cni
EOF

kubectl --context ${CLUSTER1} apply -f remote/enterprise-agent-addons.yaml
kubectl --context ${CLUSTER2} apply -f remote/enterprise-agent-addons.yaml

kubectl --context ${MGMT} apply -f remote/accesspolicy/accesspolicy.yaml

# Cleanup
cleanup