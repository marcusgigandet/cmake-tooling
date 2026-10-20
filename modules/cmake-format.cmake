include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/tooling-common.cmake")

#[[
Adds explicit cmake-format targets for formatting and checking CMake files.

The <TARGET>-cmake-format target modifies files and is registered with
tooling-fix. The <TARGET>-cmake-format-check target checks formatting without
modifying files and is registered with tooling-check.

Arguments:
  TARGET - Naming prefix; it need not name an existing build target.
  FILES  - Files to format or check, relative to the current source directory
           or absolute.
]]
function(add_cmake_format_target)
    cmake_parse_arguments(ARG "" "TARGET" "FILES" ${ARGN})
    if (NOT ARG_TARGET OR NOT ARG_FILES OR ARG_UNPARSED_ARGUMENTS OR ARG_KEYWORDS_MISSING_VALUES)
        message(FATAL_ERROR "add_cmake_format_target requires TARGET and FILES")
    endif ()
    _cmake_tooling_find(CMAKE_FORMAT_EXECUTABLE cmake-format)
    if (NOT CMAKE_FORMAT_EXECUTABLE)
        return()
    endif ()
    add_custom_target(${ARG_TARGET}-cmake-format
            COMMAND "${CMAKE_FORMAT_EXECUTABLE}" -i ${ARG_FILES}
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            VERBATIM)
    add_custom_target(${ARG_TARGET}-cmake-format-check
            COMMAND "${CMAKE_FORMAT_EXECUTABLE}" --check ${ARG_FILES}
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            VERBATIM)
    _cmake_tooling_register(fix ${ARG_TARGET}-cmake-format)
    _cmake_tooling_register(check ${ARG_TARGET}-cmake-format-check)
endfunction()

#[[
Adds an explicit cmake-lint target for checking CMake files.

The <TARGET>-cmake-lint target is registered with tooling-check. Findings
fail the target.

Arguments:
  TARGET - Naming prefix; it need not name an existing build target.
  FILES  - Files to check, relative to the current source directory or absolute.
]]
function(add_cmake_lint_target)
    cmake_parse_arguments(ARG "" "TARGET" "FILES" ${ARGN})
    if (NOT ARG_TARGET OR NOT ARG_FILES OR ARG_UNPARSED_ARGUMENTS OR ARG_KEYWORDS_MISSING_VALUES)
        message(FATAL_ERROR "add_cmake_lint_target requires TARGET and FILES")
    endif ()
    _cmake_tooling_find(CMAKE_LINT_EXECUTABLE cmake-lint)
    if (NOT CMAKE_LINT_EXECUTABLE)
        return()
    endif ()
    add_custom_target(${ARG_TARGET}-cmake-lint
            COMMAND "${CMAKE_LINT_EXECUTABLE}" ${ARG_FILES}
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            VERBATIM)
    _cmake_tooling_register(check ${ARG_TARGET}-cmake-lint)
endfunction()
