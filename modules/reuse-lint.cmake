include_guard()

#[[
Adds a custom target for REUSE linting to verify SPDX license compliance.

This target checks if the reuse tool is available and creates a lint target
that verifies the project's license compliance according to the REUSE standard.
The build will NOT fail if reuse is not installed or if linting fails.

Arguments:
  TARGET - Optional. Target to add the REUSE linting dependency to. If not provided,
           a unique target name is generated based on the current source directory.
]]
function(add_reuse_lint_target)
    set(options "")
    set(oneValueArgs TARGET)
    set(multiValueArgs "")
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    find_program(REUSE_EXECUTABLE reuse)

    if (REUSE_EXECUTABLE)
        # Generate a unique target name to avoid conflicts when multiple instances are created
        if (NOT ARG_TARGET)
            # Use a sanitized directory name as the base target name
            file(RELATIVE_PATH _relative_dir "${CMAKE_CURRENT_SOURCE_DIR}" "${CMAKE_SOURCE_DIR}")
            string(REPLACE "/" "_" _sanitized_dir "${_relative_dir}")
            string(REPLACE " " "_" _sanitized_dir "${_sanitized_dir}")
            set(_base_name "reuse-lint${_sanitized_dir}")
            string(REGEX REPLACE "^[^a-zA-Z0-9_]+" "" _base_name "${_base_name}")
            set(_lint_target "${_base_name}")
        else ()
            set(_lint_target "${ARG_TARGET}-reuse-lint")
        endif ()

        # Build comment string conditionally
        if (ARG_TARGET)
            set(_comment "Running REUSE lint for ${ARG_TARGET}")
        else ()
            set(_comment "Running REUSE lint")
        endif ()

        add_custom_target(${_lint_target}
                COMMAND
                /bin/sh -c "${REUSE_EXECUTABLE} lint || true"
                WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
                COMMENT "${_comment}"
                VERBATIM
        )

        if (ARG_TARGET)
            add_dependencies(${ARG_TARGET} ${_lint_target})
        endif ()
    else ()
        if (ARG_TARGET)
            message(STATUS "reuse tool not found, skipping REUSE lint target for ${ARG_TARGET}")
        else ()
            message(STATUS "reuse tool not found, skipping REUSE lint target")
        endif ()
    endif ()
endfunction()
