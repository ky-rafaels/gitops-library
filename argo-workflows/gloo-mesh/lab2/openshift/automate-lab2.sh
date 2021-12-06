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
echo "Installing Gloo Mesh Enterprise"
echo ""
cat mgmt/mgmt-plane-install.yaml | sed -E 's/\$\$([A-Z]+)\$\$/${\1}/g' | envsubst > tmp-mgmt-plane-install.yaml
kubectl apply -f tmp-mgmt-plane-install.yaml
echo "Waiting for deployment to complete"
kubectl rollout status deployment/dashboard -n gloo-mesh --context ${MGMT}

echo "Registering remote agents via meshctl"
ENDPOINT_GLOO_MESH=$(kubectl --context ${MGMT} -n gloo-mesh get svc enterprise-networking -o jsonpath='{.status.loadBalancer.ingress[0].*}'):9900
HOST_GLOO_MESH=$(echo ${ENDPOINT_GLOO_MESH} | cut -d: -f1)
echo "Gloo Mesh enterprise-networking exposed at ${HOST_GLOO_MESH}"
meshctl cluster register --mgmt-context=${MGMT} --remote-context=${CLUSTER1} --relay-server-address=${ENDPOINT_GLOO_MESH} enterprise cluster1 --cluster-domain cluster.local --enterprise-agent-chart-values enterprise-agent-values.yaml
meshctl cluster register --mgmt-context=${MGMT} --remote-context=${CLUSTER2} --relay-server-address=${ENDPOINT_GLOO_MESH} enterprise cluster2 --cluster-domain cluster.local --enterprise-agent-chart-values enterprise-agent-values.yaml
echo "Finding registered clusters"
kubectl --context ${MGMT} get kubernetescluster -n gloo-mesh

# Cleanup
cleanup