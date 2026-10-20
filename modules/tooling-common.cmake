include_guard(GLOBAL)

option(CMAKE_TOOLING_STRICT "Require requested tooling executables and fail on clang-tidy warnings" OFF)

#[[
Finds a tooling executable and returns its path in the calling scope.

Missing tools are skipped unless CMAKE_TOOLING_STRICT is enabled.

Arguments:
  output - Variable in which to store the executable path.
  name   - Executable name to find.
]]
function(_cmake_tooling_find output name)
    find_program(${output} NAMES "${name}")
    if (NOT ${output})
        if (CMAKE_TOOLING_STRICT)
            message(FATAL_ERROR "Required tooling executable not found: ${name}")
        endif ()
        message(STATUS "${name} not found; skipping its tooling targets")
    endif ()
    set(${output} "${${output}}" PARENT_SCOPE)
endfunction()

#[[
Registers a tooling target with an aggregate, creating it if needed.

Arguments:
  kind   - Aggregate kind: check or fix.
  target - Existing tooling target to add as a dependency.
]]
function(_cmake_tooling_register kind target)
    if (NOT TARGET tooling-${kind})
        add_custom_target(tooling-${kind})
    endif ()
    add_dependencies(tooling-${kind} ${target})
endfunction()
