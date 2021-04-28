# Copyright (c) Facebook, Inc. and its affiliates.
# All rights reserved.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

FROM hstreamdb/logdevice-builder as deps

COPY logdevice/ /LogDevice/logdevice/
COPY build/     /LogDevice/build/
COPY common/    /LogDevice/common/

# Controls the build parallelism, it defaults to the number of cores, use this
# to reduce the total memory used during compilation.
ARG PARALLEL

RUN cmake -Dthriftpy3=ON -DCMAKE_BUILD_TYPE=Release /LogDevice/logdevice/ \
    && make -j ${PARALLEL:-$(nproc)} \
    && make install -j${PARALLEL:-$(nproc)}

ENV PATH="$PATH:/usr/local/bin"
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib

CMD /bin/bash

# -----------------------------------------------------------------------------
# The client image (for haskell)
# -----------------------------------------------------------------------------

FROM ubuntu:focal AS client

RUN apt-get update && apt-get install -y --no-install-recommends \
      gcc g++ && \
    rm -rf /var/lib/apt/lists/* /tmp/*.deps && apt-get clean

COPY --from=deps /build/staging/usr/local/include/folly/ /usr/local/include/folly/
COPY --from=deps /build/staging/usr/local/include/thrift/ /usr/local/include/thrift/
COPY --from=deps /build/staging/usr/local/include/wangle/ /usr/local/include/wangle/
COPY --from=deps /build/staging/usr/local/include/fmt/ /usr/local/include/fmt/
COPY --from=deps /build/staging/usr/include/rocksdb/ /usr/local/include/rocksdb/

COPY --from=deps /LogDevice/logdevice/include/ /usr/local/include/logdevice/include/

COPY --from=deps /LogDevice/logdevice/lib/*.h /usr/local/include/logdevice/lib/

COPY --from=deps /LogDevice/logdevice/common/ /usr/local/include/logdevice/common/
RUN find /usr/local/include/logdevice/common/ -type f -name "*.cpp" | xargs rm -rf
COPY --from=deps /build/common/fb303/ /usr/local/include/common/fb303/
COPY --from=deps /build/logdevice/common/if/gen-cpp2/*.h /usr/local/include/logdevice/common/if/gen-cpp2/
COPY --from=deps /build/logdevice/common/replicated_state_machine/if/gen-cpp2/*.h /usr/local/include/logdevice/common/replicated_state_machine/if/gen-cpp2/
COPY --from=deps /build/logdevice/common/configuration/nodes/gen-cpp2/*.h /usr/local/include/logdevice/common/configuration/nodes/gen-cpp2/
COPY --from=deps /build/logdevice/common/membership/gen-cpp2/*.h /usr/local/include/logdevice/common/membership/gen-cpp2/

COPY --from=deps /build/logdevice/admin/if/gen-cpp2/*.h /usr/local/include/logdevice/admin/if/gen-cpp2/

COPY --from=deps /build/staging/usr/local/bin/thrift1 /usr/local/bin/thrift1

COPY --from=deps /usr/lib/libjemalloc* /usr/lib/
COPY --from=deps /build/staging/usr/local/lib/*.so \
                 /build/staging/usr/lib/x86_64-linux-gnu/librocksdb.so.6.6.1 \
                 /usr/local/lib/liblogdevice.so \
                 /usr/local/lib/
COPY --from=deps /build/staging/usr/local/lib/pkgconfig/libfolly.pc \
                 /build/staging/usr/local/lib/pkgconfig/fmt.pc \
                 /usr/local/lib/pkgconfig/
RUN sed -i 's/-Werror=unknown-warning-option//g' /usr/local/lib/pkgconfig/libfolly.pc

COPY --from=deps /build/logdevice/admin/if/gen-py3/logdevice/admin/clients.so \
                 /usr/local/lib/liblogdevice_admin_clients.so

RUN strip --strip-unneeded /usr/local/lib/*.so*

CMD /bin/bash

# -----------------------------------------------------------------------------
# The production image
# -----------------------------------------------------------------------------

FROM ubuntu:focal

# ldshell _requires_ utf-8
ENV LANG C.UTF-8

# Copy LogDevice user tools
COPY --from=deps /build/bin/ld* \
                 /build/bin/logdeviced \
                 /usr/local/bin/

# Python tools, ldshell, ldquery and libs
# Folly python bindings
COPY --from=deps /build/fbthrift-prefix/src/fbthrift-build/thrift/lib/py3/cybld/dist/thrift-*.whl /tmp/
# Thrift Py3
COPY --from=deps /build/folly-prefix/src/folly-build/folly/cybld/dist/folly-*.whl /tmp/
# libfolly/lib(Thrift) libraries
COPY --from=deps /build/staging/usr/local/lib/*.so /usr/local/lib/
# LDShell, LDops, ldquery, etc.
COPY --from=deps /build/python-out/dist/ldshell-*.whl /tmp/
# LogDevice client library python bindings
COPY --from=deps /build/lib/*.so /usr/local/lib/

# Install runtime dependencies for ld-dev-cluster, ldshell friends.
# To install the ldshell wheel we also need python3 build tools, as
# we depend on python-Levenshtein for which a many-linux binary wheel is not
# available; these are removed following install to keep docker image size low.
COPY docker/build_deps/ubuntu_focal_runtime.deps /tmp/logdevice_runtime.deps

RUN apt-get update && \
    apt-get install -y --no-install-recommends $(cat /tmp/logdevice_runtime.deps) \
        gcc python3-setuptools python3-dev && \
    python3 -m pip install --upgrade setuptools wheel && \
    python3 -m pip install --upgrade /tmp/folly-*.whl /tmp/ldshell-*.whl /tmp/thrift-*.whl /tmp/ldshell-*.whl && \
    strip --strip-unneeded /usr/local/lib/*.so* && \
    apt-get remove -y --auto-remove gcc python3-setuptools python3-dev && \
    rm -rf /var/lib/apt/lists/* /tmp/*.whl /tmp/*.deps
COPY --from=deps /usr/lib/libjemalloc* /usr/lib/

# ld-dev-cluster requires this
COPY --from=deps /LogDevice/logdevice/common/test/ssl_certs/logdevice_test_valid.cert \
                 /LogDevice/logdevice/common/test/ssl_certs/logdevice_test_valid_ca.cert \
                 /LogDevice/logdevice/common/test/ssl_certs/logdevice_test.key \
                 /logdevice/common/test/ssl_certs/

ENV PATH="$PATH:/usr/local/bin"
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/lib

EXPOSE 4440 4441 4443 6440

CMD /usr/local/bin/ld-dev-cluster

# vim: set ft=dockerfile:
