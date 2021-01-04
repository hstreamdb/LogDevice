# Copyright (c) Facebook, Inc. and its affiliates.
# All rights reserved.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

FROM hstreamdb/logdevice-builder as deps

COPY . /LogDevice

# Controls the build parallelism, it defaults to the number of cores, use this
# to reduce the total memory used during compilation.
ARG PARALLEL

RUN cmake -Dthriftpy3=ON -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTS=OFF /LogDevice/logdevice/ \
    && make -j ${PARALLEL:-$(nproc)}

# -----------------------------------------------------------------------------
# The all-in-one image
# -----------------------------------------------------------------------------

FROM hstreamdb/logdevice-builder as dev

COPY --from=deps /build /build
COPY . /LogDevice

# Install all logdevice components.
RUN make install -j${PARALLEL:-$(nproc)} && \
    cd /build/folly-prefix/src/folly-build/ && make install -j${PARALLEL:-$(nproc)} && \
    cp /build/staging/usr/local/lib/*.so /usr/local/lib/
# XXX
RUN rm -rf /usr/local/include/logdevice && \
    mkdir -p /usr/local/include/logdevice/include && \
    cp -R /LogDevice/logdevice/include/* /usr/local/include/logdevice/include/

# Install rockdb
RUN cd /build/rocksdb-prefix/src/rocksdb-build/ && make install -j${PARALLEL:-$(nproc)}

ENV PATH="/build/bin:$PATH"
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib

CMD /bin/bash

# -----------------------------------------------------------------------------
# The client image
# -----------------------------------------------------------------------------

FROM ubuntu:bionic AS client

COPY --from=dev /LogDevice/logdevice/build_tools/ubuntu_client.deps /tmp/ubuntu_client.deps

RUN apt-get update && apt-get install -y --no-install-recommends \
      gcc g++ $(cat /tmp/ubuntu_client.deps) && \
    rm -rf /var/lib/apt/lists/* /tmp/*.deps && apt-get clean

COPY --from=dev /usr/local/include/folly/ /usr/local/include/folly/
COPY --from=dev /usr/local/include/logdevice/ /usr/local/include/logdevice/
COPY --from=dev /usr/include/rocksdb/ /usr/local/include/rocksdb/

COPY --from=dev /usr/local/lib/liblogdevice.so \
                /build/staging/usr/local/lib/*.so \
                /usr/lib/x86_64-linux-gnu/librocksdb.so.6.6.1 \
                /usr/local/lib/logdevice/

RUN strip --strip-unneeded /usr/local/lib/logdevice/*

CMD /bin/bash

# -----------------------------------------------------------------------------
# The production image
# -----------------------------------------------------------------------------

FROM ubuntu:bionic

# ldshell _requires_ utf-8
ENV LANG C.UTF-8

# Copy LogDevice user tools
COPY --from=dev /build/bin/ld* \
                /build/bin/logdeviced \
                /usr/local/bin/

# Python tools, ldshell, ldquery and libs
# Folly python bindings
COPY --from=dev /build/fbthrift-prefix/src/fbthrift-build/thrift/lib/py3/cybld/dist/thrift-*.whl /tmp/
# Thrift Py3
COPY --from=dev /build/folly-prefix/src/folly-build/folly/cybld/dist/folly-*.whl /tmp/
# libfolly/lib(Thrift) libraries
COPY --from=dev /build/staging/usr/local/lib/*.so /usr/local/lib/
# LDShell, LDops, ldquery, etc.
COPY --from=dev /build/python-out/dist/ldshell-*.whl /tmp/
# LogDevice client library python bindings
COPY --from=dev /build/lib/*.so /usr/local/lib/

# Install runtime dependencies for ld-dev-cluster, ldshell friends.
# To install the ldshell wheel we also need python3 build tools, as
# we depend on python-Levenshtein for which a many-linux binary wheel is not
# available; these are removed following install to keep docker image size low.
COPY --from=dev /LogDevice/logdevice/build_tools/ubuntu_runtime.deps /tmp/logdevice_runtime.deps

RUN apt-get update && \
    apt-get install -y --no-install-recommends $(cat /tmp/logdevice_runtime.deps) \
        gcc python3-setuptools python3-dev && \
    python3 -m pip install --upgrade setuptools wheel && \
    python3 -m pip install --upgrade /tmp/folly-*.whl /tmp/ldshell-*.whl /tmp/thrift-*.whl /tmp/ldshell-*.whl && \
    apt-get remove -y --auto-remove gcc python3-setuptools python3-dev && \
    rm -rf /var/lib/apt/lists/* /tmp/*.whl /tmp/*.deps

EXPOSE 4440 4441 4443 6440

CMD /usr/local/bin/ld-dev-cluster

# vim: set ft=dockerfile:
