#!/bin/bash

image_build() {
    local cmd="docker build"
    if [ "$USE_BUILDAH" == "true" ]; then
        cmd="buildah bud"
    fi

    if ! ${cmd} $@
    then
      echo "Failed building image"
      exit 1
    fi
}

openshift_deployment() {
    SRC_INIT_IMAGE="docker.io/icp4apps/pipelines-utils:0.16.0-rc.1"
    INIT_IMAGE="$image_registry/$image_org/$(echo $SRC_INIT_IMAGE | cut -d'/' -f3)"

    YAML_FILE=$build_dir/openshift.yaml
    cp $base_dir/openshift/k8s.yaml $YAML_FILE
    sed -i -e "s|NGINX_IMAGE|$image_registry/$image_org/${nginx_image_name}:${INDEX_VERSION}|" $YAML_FILE
    sed -i -e "s|INIT_IMAGE|$INIT_IMAGE|" $YAML_FILE
    sed -i -e "s|DATE|$(date --utc '+%FT%TZ')|" $YAML_FILE

    mapping_file=$build_dir/image-mapping.txt
    grep -qxF "$SRC_INIT_IMAGE=$INIT_IMAGE" "$mapping_file" || echo "$SRC_INIT_IMAGE=$INIT_IMAGE" >> "$mapping_file"
}

if [ ! -z $BUILD ] && [ $BUILD == true ]
then
    if [ -z "$INDEX_VERSION" ]
    then
        export INDEX_VERSION=SNAPSHOT
    fi

    NGINX_IMAGE=nginx-ubi
    echo "BUILDING: $NGINX_IMAGE"
    if image_build \
        -t $NGINX_IMAGE \
        -f $script_dir/nginx-ubi/Dockerfile $script_dir
    then
        echo "created $NGINX_IMAGE"
    else
        >&2 echo -e "failed building $NGINX_IMAGE"
        exit 1
    fi

    nginx_arg=
    if [ -n "$NGINX_IMAGE" ]
    then
        nginx_arg="--build-arg NGINX_IMAGE=$NGINX_IMAGE"
    fi

    if [ "${nginx_image_name}" == "null" ] || [ "${nginx_image_name}" == "" ]
    then
        nginx_image_name="stack-hub-index"
    fi

    echo "BUILDING: $image_org/${nginx_image_name}:${INDEX_VERSION}"
    if image_build \
        $nginx_arg \
        -t $image_registry/$image_org/${nginx_image_name} \
        -t $image_registry/$image_org/${nginx_image_name}:${INDEX_VERSION} \
        -f $script_dir/nginx/Dockerfile $base_dir
    then
        echo "$image_registry/$image_org/${nginx_image_name}" >> $build_dir/image_list
        echo "$image_registry/$image_org/${nginx_image_name}:${INDEX_VERSION}" >> $build_dir/image_list
        echo "created $image_registry/$image_org/${nginx_image_name}:${INDEX_VERSION}"

        # generate openshift deployment yaml file
        openshift_deployment
    else
        >&2 echo -e "failed building $image_registry/$image_org/${nginx_image_name}:${INDEX_VERSION}"
        exit 1
    fi
fi