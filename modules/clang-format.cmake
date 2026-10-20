include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/tooling-common.cmake")

#[[
Adds explicit clang-format targets for formatting and checking the provided files.

The <TARGET>-format target modifies files and is registered with tooling-fix.
The <TARGET>-format-check target checks formatting without modifying files and
is registered with tooling-check. Neither target runs during a normal build.

Arguments:
  TARGET - Naming prefix for the tooling targets.
  FILES  - Files to format or check, relative to the current source directory
           or absolute.
]]
function(add_code_format_target)
    cmake_parse_arguments(ARG "" "TARGET" "FILES" ${ARGN})
    if (NOT ARG_TARGET OR NOT ARG_FILES OR ARG_UNPARSED_ARGUMENTS OR ARG_KEYWORDS_MISSING_VALUES)
        message(FATAL_ERROR "add_code_format_target requires TARGET and FILES")
    endif ()
    _cmake_tooling_find(CLANG_FORMAT_EXECUTABLE clang-format)
    if (NOT CLANG_FORMAT_EXECUTABLE)
        return()
    endif ()
    add_custom_target(${ARG_TARGET}-format
            COMMAND "${CLANG_FORMAT_EXECUTABLE}" -i ${ARG_FILES}
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            VERBATIM)
    add_custom_target(${ARG_TARGET}-format-check
            COMMAND "${CLANG_FORMAT_EXECUTABLE}" --dry-run --Werror ${ARG_FILES}
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            VERBATIM)
    _cmake_tooling_register(fix ${ARG_TARGET}-format)
    _cmake_tooling_register(check ${ARG_TARGET}-format-check)
endfunction()
