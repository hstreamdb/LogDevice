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

RUN cmake -Dthriftpy3=ON \
          -DCMAKE_BUILD_TYPE=Release \
          -DBUILD_SUBMODULES=OFF \
          -DBUILD_TESTS=OFF \
          -DCMAKE_MODULE_PATH=/usr/local/lib/cmake \
          /LogDevice/logdevice/ \
    && make -j ${PARALLEL:-$(nproc)} \
    && make install -j${PARALLEL:-$(nproc)}

CMD /bin/bash

# -----------------------------------------------------------------------------
# The client image (for haskell)
# -----------------------------------------------------------------------------

FROM ubuntu:focal AS client

RUN apt-get update && apt-get install -y --no-install-recommends \
      gcc g++ && \
    rm -rf /var/lib/apt/lists/* /tmp/*.deps && apt-get clean

# headers
COPY --from=deps /usr/local/include/fmt/ /usr/local/include/fmt/
COPY --from=deps /usr/local/include/folly/ /usr/local/include/folly/
COPY --from=deps /usr/local/include/fizz/ /usr/local/include/fizz/
COPY --from=deps /usr/local/include/wangle/ /usr/local/include/wangle/
COPY --from=deps /usr/local/include/thrift/ /usr/local/include/thrift/
COPY --from=deps /build/staging/usr/include/rocksdb/ /usr/local/include/rocksdb/

COPY --from=deps /LogDevice/logdevice/include/ /usr/local/include/logdevice/include/

COPY --from=deps /LogDevice/logdevice/lib/ /usr/local/include/logdevice/lib/
RUN find /usr/local/include/logdevice/lib/ -type f -name "*.cpp" | xargs rm -rf

COPY --from=deps /LogDevice/logdevice/common/ /usr/local/include/logdevice/common/
RUN find /usr/local/include/logdevice/common/ -type f -name "*.cpp" | xargs rm -rf
COPY --from=deps /build/common/fb303/ /usr/local/include/common/fb303/
COPY --from=deps /build/logdevice/common/if/gen-cpp2/*.h /usr/local/include/logdevice/common/if/gen-cpp2/
COPY --from=deps /build/logdevice/common/replicated_state_machine/if/gen-cpp2/*.h /usr/local/include/logdevice/common/replicated_state_machine/if/gen-cpp2/
COPY --from=deps /build/logdevice/common/configuration/nodes/gen-cpp2/*.h /usr/local/include/logdevice/common/configuration/nodes/gen-cpp2/
COPY --from=deps /build/logdevice/common/membership/gen-cpp2/*.h /usr/local/include/logdevice/common/membership/gen-cpp2/

COPY --from=deps /build/logdevice/admin/if/gen-cpp2/*.h /usr/local/include/logdevice/admin/if/gen-cpp2/

# binary
COPY --from=deps /usr/local/bin/thrift1 /usr/local/bin/thrift1

# libraries
COPY --from=deps /usr/lib/libjemalloc.so.2 /usr/lib/
COPY --from=deps /build/staging/usr/local/lib/ \
                 /build/staging/usr/lib/x86_64-linux-gnu/ \
                 /usr/local/lib/ \
                 /usr/local/lib/
RUN sed -i 's/-Werror=unknown-warning-option//g' /usr/local/lib/pkgconfig/libfolly.pc && \
    ln -sr /usr/lib/libjemalloc.so.2 /usr/lib/libjemalloc.so

RUN rm -rf /usr/local/lib/python3.8 /usr/local/lib/cmake && \
    strip --strip-unneeded /usr/local/lib/*.so*

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

COPY --from=deps /usr/lib/libjemalloc.so.2 /usr/lib/
RUN ln -sr /usr/lib/libjemalloc.so.2 /usr/lib/libjemalloc.so

COPY --from=deps /build/staging/usr/local/lib/ \
                 /build/staging/usr/lib/x86_64-linux-gnu/ \
                 /usr/local/lib/ \
                 /usr/local/lib/

RUN rm -rf /usr/local/lib/python3.8 /usr/local/lib/cmake /usr/local/lib/*.a

# Install runtime dependencies for ld-dev-cluster, ldshell friends.
# To install the ldshell wheel we also need python3 build tools, as
# we depend on python-Levenshtein for which a many-linux binary wheel is not
# available; these are removed following install to keep docker image size low.
COPY docker/build_deps/ubuntu_focal_runtime.deps /tmp/logdevice_runtime.deps

RUN apt-get update && \
    apt-get install -y --no-install-recommends $(cat /tmp/logdevice_runtime.deps) gcc && \
    strip --strip-unneeded /usr/local/lib/*.so* && \
    apt-get remove -y gcc && apt-get -y autoremove && \
    rm -rf /var/lib/apt/lists/* /tmp/*.deps

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
