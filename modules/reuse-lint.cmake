include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/tooling-common.cmake")

#[[
Adds an explicit REUSE lint target to verify SPDX license compliance.

The target is registered with tooling-check. Lint failures fail the target.
Missing reuse is skipped unless CMAKE_TOOLING_STRICT is enabled.

Arguments:
  TARGET - Optional. Naming prefix for the lint target. If not provided,
           a unique target name is generated based on the current source directory.
]]
function(add_reuse_lint_target)
    cmake_parse_arguments(ARG "" "TARGET" "" ${ARGN})
    if (ARG_UNPARSED_ARGUMENTS OR ARG_KEYWORDS_MISSING_VALUES)
        message(FATAL_ERROR "Invalid arguments to add_reuse_lint_target")
    endif ()
    _cmake_tooling_find(REUSE_EXECUTABLE reuse)
    if (NOT REUSE_EXECUTABLE)
        return()
    endif ()
    if (ARG_TARGET)
        set(_name "${ARG_TARGET}-reuse-lint")
    else ()
        string(SHA256 _id "${CMAKE_CURRENT_SOURCE_DIR}")
        string(SUBSTRING "${_id}" 0 12 _id)
        set(_name "reuse-lint-${_id}")
    endif ()
    add_custom_target(${_name}
            COMMAND "${REUSE_EXECUTABLE}" lint
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            VERBATIM)
    _cmake_tooling_register(check ${_name})
endfunction()
