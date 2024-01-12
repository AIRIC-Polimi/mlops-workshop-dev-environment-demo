#!/bin/sh

VENV_PATH=/workspaces/mlops-workshop-dev-environment-demo/.venv

if [ ! -d $VENV_PATH ]; then
    python3 -m venv $VENV_PATH
fi

if command -v nvidia-smi 2>&1 >/dev/null; then 
    $VENV_PATH/bin/pip install -r requirements.txt; 
else 
    $VENV_PATH/bin/pip install -r requirements.txt --extra-index-url https://download.pytorch.org/whl/cpu; 
fi