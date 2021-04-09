FROM ubuntu:focal

COPY docker/build_deps/ubuntu.deps /deps/ubuntu.deps
COPY external/jemalloc /deps/jemalloc

RUN apt-get update \
  && DEBIAN_FRONTEND="noninteractive" apt-get install --no-install-recommends \
      -y $(cat /deps/ubuntu.deps) \
  && rm -rf /var/lib/apt/lists/* \
  && mkdir -p /build/staging/usr/local \
  && python3 -m pip install setuptools \
  && python3 -m pip install virtualenv

ARG PARALLEL

RUN cd /deps/jemalloc && ./autogen.sh --disable-initial-exec-tls --prefix=/usr \
    && make -j ${PARALLEL:-$(nproc)} \
    && make install

# Activating the virtualenv
ENV VIRTUAL_ENV=/build/staging/usr/local
RUN python3 -m virtualenv --python=/usr/bin/python3 $VIRTUAL_ENV
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN python3 -m pip install --upgrade setuptools wheel cython

ENV CC=clang-9
ENV CXX=clang++-9

WORKDIR /build

# vim: set ft=dockerfile:
