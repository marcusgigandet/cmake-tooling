include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/instrumentation-common.cmake")

#[[
enable_target_sanitizers(TARGET target [SANITIZERS address undefined thread])

Opt in an existing C/C++ target to sanitizer instrumentation. Defaults to
address and undefined. GCC, Clang and AppleClang GNU-style drivers are supported;
the compiler and runtime are checked during configuration. Thread cannot be
combined with address. Repeated identical registrations are harmless; changing
the selection for a previously instrumented target is an error.

Compile flags are private; runtime link flags propagate to library consumers.
UBSan findings stop execution, so CTest sees them as test failures.
]]
function(enable_target_sanitizers)
    cmake_parse_arguments(ARG "" "TARGET" "SANITIZERS" ${ARGN})
    if (NOT ARG_TARGET OR ARG_UNPARSED_ARGUMENTS OR ARG_KEYWORDS_MISSING_VALUES)
        message(FATAL_ERROR "enable_target_sanitizers requires TARGET and optional SANITIZERS")
    endif ()
    _cmake_tooling_instrumentation_target("${ARG_TARGET}")
    _cmake_tooling_instrumentation_languages(_languages)
    if (NOT ARG_SANITIZERS)
        set(ARG_SANITIZERS address undefined)
    endif ()
    foreach(_sanitizer IN LISTS ARG_SANITIZERS)
        if (NOT _sanitizer MATCHES "^(address|undefined|thread)$")
            message(FATAL_ERROR "Unsupported sanitizer: ${_sanitizer}. Choose address, undefined, or thread")
        endif ()
    endforeach()
    if ("thread" IN_LIST ARG_SANITIZERS AND "address" IN_LIST ARG_SANITIZERS)
        message(FATAL_ERROR "The address and thread sanitizers cannot be combined")
    endif ()
    list(REMOVE_DUPLICATES ARG_SANITIZERS)
    list(SORT ARG_SANITIZERS)
    get_target_property(_previous "${ARG_TARGET}" _CMAKE_TOOLING_SANITIZERS)
    if (_previous)
        if (NOT "${_previous}" STREQUAL "${ARG_SANITIZERS}")
            message(FATAL_ERROR "Sanitizers already configured differently for ${ARG_TARGET}")
        endif ()
        return()
    endif ()

    list(JOIN ARG_SANITIZERS "," _selection)
    set(_link_options "-fsanitize=${_selection}")
    set(_compile_options ${_link_options} -fno-omit-frame-pointer)
    if ("undefined" IN_LIST ARG_SANITIZERS)
        list(APPEND _compile_options -fno-sanitize-recover=undefined)
    endif ()
    foreach(_language IN LISTS _languages)
        _cmake_tooling_check_instrumentation("${_language}" "${_compile_options}" "${_link_options}")
    endforeach()
    _cmake_tooling_apply_instrumentation("${ARG_TARGET}" "${_compile_options}" "${_link_options}")
    set_property(TARGET "${ARG_TARGET}" PROPERTY _CMAKE_TOOLING_SANITIZERS "${ARG_SANITIZERS}")
endfunction()
