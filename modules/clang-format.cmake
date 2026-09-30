include_guard()

#[[
Adds a custom target for clang-format as a dependency to the desired target
on the provided files.

Arguments:
  TARGET - Target to add the formatting dependency to.
  FILES  - Files to format.
]]
function(add_code_format_target)
    set(options "")
    set(oneValueArgs TARGET)
    set(multiValueArgs FILES)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    find_program(CLANG_FORMAT_EXECUTABLE clang-format REQUIRED)

    add_custom_target(${ARG_TARGET}-format
            COMMAND
            ${CLANG_FORMAT_EXECUTABLE}
            -i
            ${ARG_FILES}
            WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
            COMMENT "Running clang-format for ${ARG_TARGET}"
            VERBATIM
    )

    add_dependencies(${ARG_TARGET} ${ARG_TARGET}-format)
endfunction()
