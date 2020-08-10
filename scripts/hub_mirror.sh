#!/bin/bash -e

script_dir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
base_dir=$(cd "${script_dir}/.." && pwd)

build_dir="${base_dir}/build/appsody_stacks"


prereqs() {
    docker_cmd="docker"
    command -v $docker_cmd >/dev/null 2>&1 || { docker_cmd="podman"; }
    command -v $docker_cmd >/dev/null 2>&1 || { echo "Unable to deploy images: docker or podman are not installed."; exit 1; }

    command -v oc >/dev/null 2>&1 || { echo "Unable to mirror images or deploy stack-hub-index: oc is not installed."; exit 1; }
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
    oc image mirror -f "$file" --insecure
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
fi
