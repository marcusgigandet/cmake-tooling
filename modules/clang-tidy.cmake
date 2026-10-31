include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/tooling-common.cmake")

#[[
Adds a custom target for clang-tidy analysis on the provided files.

By default the analysis target is standalone and can be run on demand:
  cmake --build <build-dir> --target <TARGET>-clang-tidy
It depends on the given TARGET so compilation artifacts such as module
interface BMIs exist before the analysis runs.
With ON_BUILD, analysis runs after source preparation and before compilation
instead, and is required by the named target on every build.

clang-tidy uses the compile database, so CMAKE_EXPORT_COMPILE_COMMANDS must
be enabled and every file passed to FILES must have a matching entry in it.

Arguments:
  TARGET       - Target whose name is used for the analysis target
                 ("<TARGET>-clang-tidy") and which is built first.
  FILES        - Files to analyze.
  CHECKS       - Optional. Comma-separated clang-tidy checks overriding any
                 .clang-tidy configuration (e.g. "modernize-*,-modernize-use-trailing-return-type").
  HEADER_FILTER - Optional. Regular expression for clang-tidy's --header-filter.
  ON_BUILD     - Opt in to analysis before compilation; requires clang-tidy.
                 Leave omitted when analysis needs compilation artifacts such as BMIs.
]]
function(add_clang_tidy_target)
    set(options "ON_BUILD")
    set(oneValueArgs TARGET HEADER_FILTER)
    set(multiValueArgs FILES CHECKS)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if (NOT ARG_TARGET OR NOT TARGET "${ARG_TARGET}" OR NOT ARG_FILES OR ARG_UNPARSED_ARGUMENTS OR ARG_KEYWORDS_MISSING_VALUES)
        message(FATAL_ERROR "add_clang_tidy_target requires an existing TARGET and FILES")
    endif ()

    if (ARG_ON_BUILD)
        _cmake_tooling_find(CLANG_TIDY_EXECUTABLE clang-tidy REQUIRED)
    else ()
        _cmake_tooling_find(CLANG_TIDY_EXECUTABLE clang-tidy)
    endif ()
    if (NOT CLANG_TIDY_EXECUTABLE)
        return()
    endif ()

    if (NOT CMAKE_EXPORT_COMPILE_COMMANDS)
        message(FATAL_ERROR
                "add_clang_tidy_target requires CMAKE_EXPORT_COMPILE_COMMANDS to be enabled."
        )
    endif ()

    set(_clang_tidy_args -p ${CMAKE_BINARY_DIR})

    if (CMAKE_TOOLING_STRICT)
        list(APPEND _clang_tidy_args "--warnings-as-errors=*")
    endif ()

    if (ARG_CHECKS)
        list(JOIN ARG_CHECKS "," _checks)
        list(APPEND _clang_tidy_args "-checks=${_checks}")
    endif ()

    if (ARG_HEADER_FILTER)
        list(APPEND _clang_tidy_args "-header-filter=${ARG_HEADER_FILTER}")
    endif ()

    # Run from the build directory so that response files referenced by the
    # compile database resolve.
    add_custom_target(${ARG_TARGET}-clang-tidy
            COMMAND
            "${CLANG_TIDY_EXECUTABLE}"
            ${_clang_tidy_args}
            ${ARG_FILES}
            WORKING_DIRECTORY "${CMAKE_BINARY_DIR}"
            COMMENT "Running clang-tidy for ${ARG_TARGET}"
            VERBATIM
    )

    if (ARG_ON_BUILD)
        _cmake_tooling_add_build_dependency("${ARG_TARGET}" "${ARG_TARGET}-clang-tidy" analyze
                FILES ${ARG_FILES})
    else ()
        add_dependencies(${ARG_TARGET}-clang-tidy ${ARG_TARGET})
    endif ()
    _cmake_tooling_register(check ${ARG_TARGET}-clang-tidy)
endfunction()
