#!/bin/bash
set -e -u -x

project_path=${1:-.}

function repair_wheel {
    wheel="$1"
    if ! auditwheel show "$wheel"; then
        echo "Skipping non-platform wheel $wheel"
    else
        auditwheel repair "$wheel" --plat "$PLAT" -w wheelhouse/
    fi
}

# Compile wheels
for PYBIN in /opt/python/*/bin; do
    "${PYBIN}/pip3" wheel $project_path --no-deps -w wheelhouse/
done

# Bundle external shared libraries into the wheels
for whl in wheelhouse/*.whl; do
    repair_wheel "$whl"
done

# Install packages and test
for PYBIN in /opt/python/*/bin; do
    "${PYBIN}/pip" install pycma --no-index -f wheelhouse
    # (cd "$HOME"; "${PYBIN}/nosetests" pymanylinuxdemo)
done
