#!/bin/bash -e

script_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
base_dir=$(cd "${script_dir}/.." && pwd)

build_dir="${base_dir}/build/appsody_stacks"


prereqs() {
    if [ -x "$(command -v podman)" ]; then
        docker_cmd="podman"
        if [ -n "${REGISTRY_AUTH_FILE}" ]; then
            oc_image_args=(-a "${REGISTRY_AUTH_FILE}")
        elif [ -n "${XDG_RUNTIME_DIR}" ] && [ -e "${XDG_RUNTIME_DIR}/containers/auth.json" ]; then
            export REGISTRY_AUTH_FILE="${XDG_RUNTIME_DIR}/containers/auth.json"
            oc_image_args=(-a "${REGISTRY_AUTH_FILE}")
        fi
    elif [ -x "$(command -v docker)" ]; then
        docker_cmd="docker"
    else
        echo "Unable to deploy images: docker or podman are not installed."
        exit 1
    fi

    command -v oc >/dev/null 2>&1 || { echo "Unable to mirror images or deploy stack-hub-index: oc is not installed."; exit 1; }
}

image_tag() {
    echo "== Tagging $@"
    $docker_cmd tag $1 $2
}

image_push() {
    local name=$@
    echo "== Pushing $name"
    if [ "$docker_cmd" == "podman" ]; then
        podman push --tls-verify=false $name
    else
        docker push $name
    fi
}

image_mirror() {
    local file=$1
    while IFS='=' read -r src_image dst_image
    do
        if [[ "$src_image" = "dev.local"* ]]; then
            image_tag "$src_image" "$dst_image"
            image_push "$dst_image"
        else
            oc image mirror --insecure ${oc_image_args[@]} --filter-by-os='.*' "$src_image" "$dst_image"
        fi
    done < $file
}

get_route() {
    for i in 1 2 3 4 5 6 7 8 9 10; do
        ROUTE=$(oc get route stack-hub-index --no-headers -o=jsonpath='{.status.ingress[0].host}')
        if [ -z "$ROUTE" ]; then
            sleep 1
        else
            echo "http://$ROUTE"
            return
        fi
    done
    echo "Unable to get route for stack-hub-index"
    exit 1
}

# check needed tools are installed
prereqs

# push nginx image
if [ -f "$build_dir/image_list" ]; then
    echo "= Pushing stack hub index image into your registry."
    while read line
    do
        if [ "$line" != "" ]; then
            image_push $line
        fi
    done < $build_dir/image_list
fi

# mirror stack images
if [ -f "$build_dir/image-mapping.txt" ]; then
    echo "= Mirroring stack and related images into your registry."
    image_mirror "$build_dir/image-mapping.txt"
fi 

# deploy nginx container
if [ -f "$build_dir/openshift.yaml" ]; then
    echo "= Deploying stack hub index container into your cluster."
    oc apply -f "$build_dir/openshift.yaml"

    INDEX_YAML=$(cd $build_dir/index-src && ls *-index.yaml | head -n 1)
    STACK_HUB_ROUTE=$(get_route)
    echo "== Your stack hub index is available at: $STACK_HUB_ROUTE/$INDEX_YAML"
fi
