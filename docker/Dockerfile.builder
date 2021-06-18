FROM ubuntu:focal

COPY docker/build_deps/ubuntu.deps /deps/ubuntu.deps
RUN apt-get update \
  && DEBIAN_FRONTEND="noninteractive" apt-get install --no-install-recommends \
      -y $(cat /deps/ubuntu.deps) ninja-build \
  && rm -rf /var/lib/apt/lists/*

# Activating the virtualenv
ENV VIRTUAL_ENV=/build/staging/usr/local
ENV PATH="$VIRTUAL_ENV/bin:/usr/local/bin:$PATH"
RUN mkdir -p /build/staging/usr/local && \
  python3 -m pip install setuptools virtualenv && \
  python3 -m virtualenv --python=/usr/bin/python3 $VIRTUAL_ENV && \
  python3 -m pip install -U wheel cython

ARG PARALLEL
ENV CC=clang
ENV CXX=clang++

# jemalloc
COPY external/jemalloc /deps/jemalloc
RUN cd /deps/jemalloc && ./autogen.sh --disable-initial-exec-tls --prefix=/usr && \
    make -j ${PARALLEL:-$(nproc)} && \
    make install && rm -rf /deps/jemalloc

# libfmt
COPY logdevice/external/fmt /deps/fmt
RUN cd /deps/fmt && \
    cmake -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_CXX_STANDARD=17 \
          -DCMAKE_POSITION_INDEPENDENT_CODE=True \
          -DFMT_TEST=OFF . && \
    make -j ${PARALLEL:-$(nproc)} && make install && rm -rf /deps/fmt

# libfolly
COPY logdevice/external/folly /deps/folly
RUN cd /deps/folly && \
    cmake -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_CXX_STANDARD=17 \
          -DCMAKE_POSITION_INDEPENDENT_CODE=True \
          -DBUILD_SHARED_LIBS=ON \
          -DPYTHON_EXTENSIONS=True \
          -Dthriftpy3=ON \
          # Folly doesn't build on clang without this flag \
          # ((https://github.com/facebook/folly/issues/976)) \
          -DFOLLY_USE_JEMALLOC=OFF \
          . && \
    make -j ${PARALLEL:-$(nproc)} && make install && \
    cp folly/cybld/dist/folly-*.whl /deps/ && \
    python3 -m pip install --force-reinstall /deps/folly-*.whl && \
    rm -rf /deps/folly

# libfizz
COPY logdevice/external/fizz /deps/fizz
RUN cd /deps/fizz && \
    cmake -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_CXX_STANDARD=17 \
          -DCMAKE_POSITION_INDEPENDENT_CODE=True \
          -DBUILD_SHARED_LIBS=ON \
          -DBUILD_TESTS=OFF \
          -DBUILD_EXAMPLES=OFF \
          ./fizz && \
    make -j ${PARALLEL:-$(nproc)} && make install && \
    cp /deps/fizz/build/fbcode_builder/CMake/FindSodium.cmake /usr/local/lib/cmake/FindSodium.cmake && \
    rm -rf /deps/fizz

# libwangle
COPY logdevice/external/wangle /deps/wangle
RUN cd /deps/wangle && \
    cmake -DCMAKE_BUILD_TYPE=Release \
          -DCMAKE_CXX_STANDARD=17 \
          -DCMAKE_POSITION_INDEPENDENT_CODE=True \
          -DBUILD_SHARED_LIBS=ON \
          -DBUILD_TESTS=OFF \
          ./wangle && \
    make -j ${PARALLEL:-$(nproc)} && \
    make install && rm -rf /deps/wangle

# fbthrift
#
# FIXME: cmake can not find python-fix
# - https://github.com/facebook/fbthrift/issues/376
# - https://github.com/facebook/fbthrift/issues/415
COPY logdevice/external/fbthrift /deps/fbthrift
RUN python3 /deps/fbthrift/build/fbcode_builder/getdeps.py build --allow-system-packages python-six --install-dir /tmp/six && \
    mv /tmp/six/lib/cmake/python-six /usr/local/lib/cmake/ && \
    mv /tmp/six/lib/fb-py-libs /usr/local/lib/ && \
    rm -rf /tmp/*
# doesn't build on clang with c++17
# e.g. https://github.com/pybind/pybind11/issues/1818
RUN export CC=gcc && \
    export CXX=g++ && \
    cd /deps/fbthrift && \
    cmake -DCMAKE_BUILD_TYPE=Release \
          -Dthriftpy3=ON \
          -DCMAKE_CXX_STANDARD=17 \
          -DCMAKE_POSITION_INDEPENDENT_CODE=True \
          -DBUILD_SHARED_LIBS=ON \
          -DCMAKE_MODULE_PATH=/usr/local/lib/cmake/ \
          -Denable_tests=OFF \
          . && \
    make -j ${PARALLEL:-$(nproc)} && make install && \
    cp thrift/lib/py3/cybld/dist/thrift-*.whl /deps/ && \
    python3 -m pip install --force-reinstall /deps/thrift-*.whl && \
    rm -rf /deps/fbthrift

ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib
WORKDIR /build
CMD /bin/bash

# vim: set ft=dockerfile:
