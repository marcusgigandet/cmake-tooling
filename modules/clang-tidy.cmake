include_guard()

#[[
Adds a custom target for clang-tidy analysis on the provided files.

The analysis target is standalone (it is not attached to ALL) so it can be
run on demand:
  cmake --build <build-dir> --target <TARGET>-clang-tidy
It depends on the given TARGET so compilation artifacts such as module
interface BMIs exist before the analysis runs.

clang-tidy uses the compile database, so CMAKE_EXPORT_COMPILE_COMMANDS must
be enabled and every file passed to FILES must have a matching entry in it.

Arguments:
  TARGET       - Target whose name is used for the analysis target
                 ("<TARGET>-clang-tidy") and which is built first.
  FILES        - Files to analyze.
  CHECKS       - Optional. Comma-separated clang-tidy checks overriding any
                 .clang-tidy configuration (e.g. "modernize-*,-modernize-use-trailing-return-type").
  HEADER_FILTER - Optional. Regular expression for clang-tidy's --header-filter.
]]
function(add_clang_tidy_target)
    set(options "")
    set(oneValueArgs TARGET HEADER_FILTER)
    set(multiValueArgs FILES CHECKS)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if (NOT CMAKE_EXPORT_COMPILE_COMMANDS)
        message(FATAL_ERROR
                "add_clang_tidy_target requires CMAKE_EXPORT_COMPILE_COMMANDS to be enabled."
        )
    endif ()

    find_program(CLANG_TIDY_EXECUTABLE clang-tidy REQUIRED)

    set(_clang_tidy_args -p ${CMAKE_BINARY_DIR})

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
            ${CLANG_TIDY_EXECUTABLE}
            ${_clang_tidy_args}
            ${ARG_FILES}
            WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
            COMMENT "Running clang-tidy for ${ARG_TARGET}"
            VERBATIM
    )

    add_dependencies(${ARG_TARGET}-clang-tidy ${ARG_TARGET})
endfunction()
