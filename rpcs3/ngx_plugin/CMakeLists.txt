if(NOT UNIX OR APPLE)
    return()
endif()

set(DLSS_SDK "" CACHE PATH "Path to the NVIDIA DLSS SDK")

if(NOT DLSS_SDK)
    message(STATUS "DLSS SDK not configured; Linux NGX plugin disabled")
    return()
endif()

set(DLSS_NGX_INCLUDE "${DLSS_SDK}/include")
set(DLSS_NGX_LIBRARY "${DLSS_SDK}/lib/Linux_x86_64/libnvsdk_ngx.a")
set(DLSS_NGX_RUNTIME_DIR "${DLSS_SDK}/lib/Linux_x86_64/rel")

if(NOT EXISTS "${DLSS_NGX_INCLUDE}/nvsdk_ngx_vk.h")
    message(FATAL_ERROR "DLSS SDK headers not found: ${DLSS_NGX_INCLUDE}")
endif()

if(NOT EXISTS "${DLSS_NGX_LIBRARY}")
    message(FATAL_ERROR "Linux NGX static library not found: ${DLSS_NGX_LIBRARY}")
endif()

file(GLOB DLSS_NGX_SR_RUNTIME
    "${DLSS_NGX_RUNTIME_DIR}/libnvidia-ngx-dlss.so.*"
)
file(GLOB DLSS_NGX_FG_RUNTIME
    "${DLSS_NGX_RUNTIME_DIR}/libnvidia-ngx-dlssg.so.*"
)
file(GLOB DLSS_NGX_D_RUNTIME
    "${DLSS_NGX_RUNTIME_DIR}/libnvidia-ngx-dlssd.so.*"
)

foreach(_runtime IN ITEMS
    DLSS_NGX_SR_RUNTIME
    DLSS_NGX_FG_RUNTIME
    DLSS_NGX_D_RUNTIME
)
    list(LENGTH ${_runtime} _runtime_count)
    if(NOT _runtime_count EQUAL 1)
        message(FATAL_ERROR
            "Expected exactly one ${_runtime} in ${DLSS_NGX_RUNTIME_DIR}; found ${_runtime_count}")
    endif()
endforeach()

set(DLSS_NGX_RUNTIME
    ${DLSS_NGX_SR_RUNTIME}
    ${DLSS_NGX_FG_RUNTIME}
    ${DLSS_NGX_D_RUNTIME}
)

add_library(rpcs3_ngx SHARED rpcs3_ngx.cpp)

target_include_directories(rpcs3_ngx SYSTEM PRIVATE
    "${DLSS_NGX_INCLUDE}"
)

if(CMAKE_CXX_COMPILER_ID MATCHES "Clang|GNU")
    target_compile_options(rpcs3_ngx PRIVATE
        -Wno-error=old-style-cast
    )
endif()

target_link_libraries(rpcs3_ngx PRIVATE
    3rdparty_vulkan
    "${DLSS_NGX_LIBRARY}"
    ${CMAKE_DL_LIBS}
    stdc++
)

set_target_properties(rpcs3_ngx PROPERTIES
    OUTPUT_NAME "rpcs3_ngx"
    CXX_VISIBILITY_PRESET hidden
    VISIBILITY_INLINES_HIDDEN YES
    BUILD_RPATH "$ORIGIN"
    INSTALL_RPATH "$ORIGIN"
    INSTALL_RPATH_USE_LINK_PATH FALSE
)

install(TARGETS rpcs3_ngx
    LIBRARY DESTINATION bin
)

install(FILES ${DLSS_NGX_RUNTIME}
    DESTINATION bin
)
