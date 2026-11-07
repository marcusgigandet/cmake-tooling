include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/tooling-common.cmake")

#[[
Adds explicit clang-format targets for formatting and checking the provided files.

The <TARGET>-format target modifies files and is registered with tooling-fix.
The <TARGET>-format-check target checks formatting without modifying files and
is registered with tooling-check. By default neither target runs during a normal build.

Arguments:
  TARGET - Naming prefix for the tooling targets.
  FILES  - Files to format or check, relative to the current source directory
           or absolute.
  ON_BUILD - Opt in to formatting before normal builds; requires clang-format.
  DEPENDENCY_TARGETS - Additional targets that must wait for source preparation.
]]
function(add_code_format_target)
    cmake_parse_arguments(ARG "ON_BUILD" "TARGET" "FILES;DEPENDENCY_TARGETS" ${ARGN})
    if (NOT ARG_TARGET OR NOT ARG_FILES OR ARG_UNPARSED_ARGUMENTS OR ARG_KEYWORDS_MISSING_VALUES)
        message(FATAL_ERROR "add_code_format_target requires TARGET and FILES")
    endif ()
    if (ARG_DEPENDENCY_TARGETS AND NOT ARG_ON_BUILD)
        message(FATAL_ERROR "DEPENDENCY_TARGETS requires ON_BUILD")
    endif ()
    if (ARG_ON_BUILD)
        _cmake_tooling_find(CLANG_FORMAT_EXECUTABLE clang-format REQUIRED)
    else ()
        _cmake_tooling_find(CLANG_FORMAT_EXECUTABLE clang-format)
    endif ()
    if (NOT CLANG_FORMAT_EXECUTABLE)
        return()
    endif ()
    add_custom_target(${ARG_TARGET}-format
            COMMAND "${CLANG_FORMAT_EXECUTABLE}" -i ${ARG_FILES}
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            COMMENT "Formatting sources for ${ARG_TARGET}"
            VERBATIM)
    add_custom_target(${ARG_TARGET}-format-check
            COMMAND "${CLANG_FORMAT_EXECUTABLE}" --dry-run --Werror ${ARG_FILES}
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            COMMENT "Checking source formatting for ${ARG_TARGET}"
            VERBATIM)
    _cmake_tooling_register(fix ${ARG_TARGET}-format)
    _cmake_tooling_register(check ${ARG_TARGET}-format-check)
    if (ARG_ON_BUILD)
        _cmake_tooling_add_build_dependency("${ARG_TARGET}" "${ARG_TARGET}-format" format
                FILES ${ARG_FILES} TARGETS ${ARG_DEPENDENCY_TARGETS})
    endif ()
endfunction()
