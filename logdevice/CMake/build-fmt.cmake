# Copyright (c) 2017-present, Facebook, Inc.
# All rights reserved.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

include(ExternalProject)

ExternalProject_Add(fmt
    PREFIX "${CMAKE_CURRENT_BINARY_DIR}"
    SOURCE_DIR "${LOGDEVICE_DIR}/external/fmt"
    DOWNLOAD_COMMAND ""
    CMAKE_ARGS -DCMAKE_POSITION_INDEPENDENT_CODE=True
        -DCXX_STD=gnu++17
        -DCMAKE_CXX_STANDARD=17
        -DCMAKE_PREFIX_PATH=${LOGDEVICE_STAGING_DIR}/usr/local
        -DFMT_TEST=OFF
    INSTALL_COMMAND $(MAKE) install DESTDIR=${LOGDEVICE_STAGING_DIR}
    )

# Specify include dir
ExternalProject_Get_Property(fmt SOURCE_DIR)
ExternalProject_Get_Property(fmt BINARY_DIR)

set(FMT_LIBRARIES
  ${BINARY_DIR}/libfmt.a
  )
message(STATUS "fmt Library: ${FMT_LIBRARIES}")

mark_as_advanced(
  FMT_LIBRARIES
)
