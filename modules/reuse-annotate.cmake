include_guard()

#[[
Adds a custom target to add REUSE-compliant license headers to files.

This target creates a custom target that adds SPDX license headers to the
specified files using the reuse annotate command. Only Unix systems are supported.
The build will NOT fail if reuse is not installed.

Arguments:
  TARGET - Optional. Target to add the header dependency to. If not provided,
           a unique target name is generated based on the current source directory.
  LICENSE - SPDX license identifier (e.g., "LGPL-3.0-or-later").
  USERS - Copyright holder(s) for SPDX-FileCopyrightText.
  FILES - List of files to add headers to.
  FLAGS - String of additional arguments to pass.
]]
function(add_reuse_header_target)
    set(options "")
    set(oneValueArgs TARGET LICENSE USERS FLAGS)
    set(multiValueArgs FILES)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    find_program(REUSE_EXECUTABLE reuse)

    if (REUSE_EXECUTABLE)
        # Generate a unique target name to avoid conflicts when multiple instances are created
        if (NOT ARG_TARGET)
            # Use a sanitized directory name as the base target name
            file(RELATIVE_PATH _relative_dir "${CMAKE_CURRENT_SOURCE_DIR}" "${CMAKE_SOURCE_DIR}")
            string(REPLACE "/" "_" _sanitized_dir "${_relative_dir}")
            string(REPLACE " " "_" _sanitized_dir "${_sanitized_dir}")
            set(_base_name "reuse-headers${_sanitized_dir}")
            string(REGEX REPLACE "^[^a-zA-Z0-9_]+" "" _base_name "${_base_name}")
            set(_headers_target "${_base_name}")
        else ()
            set(_headers_target "${ARG_TARGET}-reuse-headers")
        endif ()

        # Build comment string conditionally
        if (ARG_TARGET)
            set(_comment "Adding REUSE license headers for ${ARG_TARGET}")
        else ()
            set(_comment "Adding REUSE license headers")
        endif ()

        add_custom_target(${_headers_target}
                COMMAND
                ${REUSE_EXECUTABLE} annotate --license ${ARG_LICENSE} --copyright "${ARG_USERS}" ${ARG_FLAGS} ${ARG_FILES}
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
                COMMENT "${_comment}"
                VERBATIM
        )

        if (ARG_TARGET)
            add_dependencies(${ARG_TARGET} ${_headers_target})
        endif ()
    else ()
        if (ARG_TARGET)
            message(STATUS "reuse tool not found, skipping REUSE header target for ${ARG_TARGET}")
        else ()
            message(STATUS "reuse tool not found, skipping REUSE header target")
        endif ()
    endif ()
endfunction()
