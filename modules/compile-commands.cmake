include_guard()

#[[
Adds a custom target that copies compile_commands.json from the build
directory to the project root on every build, so tools like clangd find it.

Arguments:
  Target - Target to attach the task as a dependency.
]]
function(add_compile_commands_copy_target)
    if (NOT CMAKE_EXPORT_COMPILE_COMMANDS OR NOT PROJECT_IS_TOP_LEVEL)
        return()
    endif ()

    set(options "")
    set(oneValueArgs TARGET)
    set(multiValueArgs "")
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if (NOT ARG_TARGET)
        message(FATAL_ERROR "TARGET must be set.")
    endif ()

    add_custom_command(TARGET ${ARG_TARGET} POST_BUILD
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
            ${CMAKE_BINARY_DIR}/compile_commands.json
            ${PROJECT_SOURCE_DIR}/compile_commands.json
            COMMENT "Copying compile_commands.json to the project root"
            VERBATIM
    )
endfunction()
