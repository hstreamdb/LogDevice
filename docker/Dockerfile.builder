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
  python3 -m virtualenv --python=/usr/bin/python3 $VIRTUAL_ENV

ARG PARALLEL

COPY external/jemalloc /deps/jemalloc
RUN cd /deps/jemalloc && ./autogen.sh --disable-initial-exec-tls --prefix=/usr && \
    make -j ${PARALLEL:-$(nproc)} && \
    make install && rm -rf /deps/jemalloc

ENV CC=clang-9
ENV CXX=clang++-9
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib

RUN python3 -m pip install -U wheel cython

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
COPY logdevice/external/fbthrift /deps/fbthrift
RUN cd /deps/fbthrift && \
    cmake -DCMAKE_BUILD_TYPE=Release \
          -Dthriftpy3=ON \
          -DCMAKE_CXX_STANDARD=17 \
          -DCMAKE_POSITION_INDEPENDENT_CODE=True \
          -DBUILD_SHARED_LIBS=ON \
          -Denable_tests=OFF \
          . && \
    make -j ${PARALLEL:-$(nproc)} && make install && \
    cp thrift/lib/py3/cybld/dist/thrift-*.whl /deps/ && \
    python3 -m pip install --force-reinstall /deps/thrift-*.whl && \
    rm -rf /deps/fbthrift

WORKDIR /build
CMD /bin/bash

# vim: set ft=dockerfile:
