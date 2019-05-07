set(lib cerf)
if (${CERF_CPP})
    set(lib cerfcpp)
endif()
message(STATUS
    "libcerf/lib: build library ${lib}, CERF_CPP=${CERF_CPP}, shared=${BUILD_SHARED_LIBS}")

set(cerf_LIBRARY ${lib} PARENT_SCOPE)

set(src_files erfcx.c err_fcts.c im_w_of_x.c w_of_z.c width.c)
set(inc_files cerf.h)

if (${CERF_CPP})
    set_property(SOURCE ${src_files} PROPERTY LANGUAGE CXX)
endif()

add_library(${lib} ${src_files})

set_target_properties(
    ${lib} PROPERTIES
    OUTPUT_NAME ${lib}
    VERSION ${CERF_VERSION}
    SOVERSION ${CERF_SOVERSION})
if (${CERF_CPP})
    set_target_properties(${lib} PROPERTIES LINKER_LANGUAGE CXX)
endif()

if(NOT MSVC)
    target_link_libraries(${lib} m)
endif()

if (LIB_INSTALL)
    install(
        TARGETS ${lib} LIBRARY
        DESTINATION ${destination}/lib
        COMPONENT Libraries)
    install(
        FILES ${inc_files}
        DESTINATION ${destination}/include
        COMPONENT Headers)
endif()
