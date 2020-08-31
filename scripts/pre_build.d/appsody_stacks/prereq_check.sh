#!/bin/bash

exit_script=0
python_exe=""

if [ ! -x "$(command -v docker)" ] && [ ! -x "$(command -v buildah)" ]; then
    echo "Unable to build stack-hub-index: docker or buildah are not installed."
    exit_script=1
fi    

if ! yq --version > /dev/null 2>&1
then
    echo "Error: 'yq' command is not installed or not available on the path"
    exit_script=1
fi

if [ "$CODEWIND_INDEX" == "true" ]
then
    if ! python3 --version > /dev/null 2>&1
    then
        if ! python --version > /dev/null 2>&1
        then
            echo "Error: 'python' command is not installed or not available on the path"
            exit_script=1
        else
            python_exe="python"
        fi
    else
        python_exe="python3"
    fi
    
    if [ $python_exe != "" ]
    then 
        if ! ${python_exe} -c "import yaml" > /dev/null 2>&1
        then
            echo "Error: Python 'yaml' package not installed"
            exit_script=1
        fi
    fi
fi

if [ $exit_script != 0 ]
then
    echo "Error: Some required dependencies are missing, exiting script"
    exit 1
fi

