include_guard()

#[[
Adds a custom target that copies compile_commands.json from the build
directory to the project root on every build, so tools like clangd find it.

Does nothing unless the project is top-level and CMAKE_EXPORT_COMPILE_COMMANDS
is enabled. The target is added to ALL so the copy stays in sync with the build.
]]
function(add_compile_commands_copy_target)
    if (NOT CMAKE_EXPORT_COMPILE_COMMANDS OR NOT PROJECT_IS_TOP_LEVEL)
        return()
    endif ()

    add_custom_target(copy-compile-commands
            ALL
            COMMAND ${CMAKE_COMMAND} -E copy_if_different
            ${CMAKE_BINARY_DIR}/compile_commands.json
            ${PROJECT_SOURCE_DIR}/compile_commands.json
            COMMENT "Copying compile_commands.json to the project root"
            VERBATIM
    )
endfunction()
