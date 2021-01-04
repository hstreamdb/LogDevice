FROM ubuntu:bionic

COPY logdevice/build_tools/ubuntu.deps /tmp/ubuntu.deps

RUN apt-get update \
    && apt-get install --no-install-recommends \
      -y $(cat /tmp/ubuntu.deps) \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /build/staging/usr/local \
    && python3 -m pip install setuptools \
    && python3 -m pip install virtualenv

# Activating the virtualenv
ENV VIRTUAL_ENV=/build/staging/usr/local
RUN python3 -m virtualenv --python=/usr/bin/python3 $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN python3 -m pip install --upgrade setuptools wheel cython

# FIXME: https://gitlab.kitware.com/cmake/cmake/-/merge_requests/201/diffs
# it seems fixed since the cmake 3.11
RUN sed -i '/_Boost_PYTHON_HEADERS/a \ \ set(_Boost_PYTHON3_HEADERS             "${_Boost_PYTHON_HEADERS}")' /usr/share/cmake-3.10/Modules/FindBoost.cmake

ENV CC=clang-9
ENV CXX=clang++-9

WORKDIR /build

# vim: set ft=dockerfile:
