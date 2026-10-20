include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/tooling-common.cmake")

#[[
Adds a custom target to add REUSE-compliant license headers to files.

This target creates a custom target that adds SPDX license headers to the
specified files using the reuse annotate command. Runs only when explicitly requested.
Missing reuse is skipped unless CMAKE_TOOLING_STRICT is enabled.

Arguments:
  TARGET - Optional. Naming prefix for the annotation target. If not provided,
           a unique target name is generated based on the current source directory.
  LICENSE - SPDX license identifier (e.g., "LGPL-3.0-or-later").
  USERS - Copyright holder(s) for SPDX-FileCopyrightText.
  FILES - List of files to add headers to.
  FLAGS - List of additional arguments to pass.
]]
function(add_reuse_header_target)
    set(options "")
    set(oneValueArgs TARGET LICENSE)
    set(multiValueArgs FILES USERS FLAGS)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if (NOT ARG_LICENSE OR NOT ARG_USERS OR NOT ARG_FILES OR ARG_UNPARSED_ARGUMENTS OR ARG_KEYWORDS_MISSING_VALUES)
        message(FATAL_ERROR "add_reuse_header_target requires LICENSE, USERS and FILES")
    endif ()
    _cmake_tooling_find(REUSE_EXECUTABLE reuse)

    if (REUSE_EXECUTABLE)
        # Generate a unique target name to avoid conflicts when multiple instances are created
        if (NOT ARG_TARGET)
            string(SHA256 _id "${CMAKE_CURRENT_SOURCE_DIR}")
            string(SUBSTRING "${_id}" 0 12 _id)
            set(_headers_target "reuse-headers-${_id}")
        else ()
            set(_headers_target "${ARG_TARGET}-reuse-headers")
        endif ()

        # Build comment string conditionally
        if (ARG_TARGET)
            set(_comment "Adding REUSE license headers for ${ARG_TARGET}")
        else ()
            set(_comment "Adding REUSE license headers")
        endif ()

        set(_copyright_args)
        foreach(_user IN LISTS ARG_USERS)
            list(APPEND _copyright_args --copyright "${_user}")
        endforeach()

        add_custom_target(${_headers_target}
                COMMAND
                "${REUSE_EXECUTABLE}" annotate --license "${ARG_LICENSE}" ${_copyright_args} --skip-existing ${ARG_FLAGS} ${ARG_FILES}
                WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
                COMMENT "${_comment}"
                VERBATIM
        )

        _cmake_tooling_register(fix ${_headers_target})
    else ()
        if (ARG_TARGET)
            message(STATUS "reuse tool not found, skipping REUSE header target for ${ARG_TARGET}")
        else ()
            message(STATUS "reuse tool not found, skipping REUSE header target")
        endif ()
    endif ()
endfunction()
