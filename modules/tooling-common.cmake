include_guard(GLOBAL)

option(CMAKE_TOOLING_STRICT "Require requested tooling executables and fail on clang-tidy warnings" OFF)

#[[
Finds a tooling executable and returns its path in the calling scope.

Missing tools are skipped unless CMAKE_TOOLING_STRICT is enabled or REQUIRED is given.

Arguments:
  output - Variable in which to store the executable path.
  name   - Executable name to find.
  REQUIRED - Fail when missing, even if CMAKE_TOOLING_STRICT is disabled.
]]
function(_cmake_tooling_find output name)
    cmake_parse_arguments(ARG "REQUIRED" "" "" ${ARGN})
    find_program(${output} NAMES "${name}")
    if (NOT ${output})
        if (CMAKE_TOOLING_STRICT OR ARG_REQUIRED)
            message(FATAL_ERROR "Required tooling executable not found: ${name}")
        endif ()
        message(STATUS "${name} not found; skipping its tooling targets")
    endif ()
    set(${output} "${${output}}" PARENT_SCOPE)
endfunction()

#[[
Registers opt-in source preparation. Finalization is deferred until all consumer
targets exist, so registration order does not constrain dependency targets.
]]
function(_cmake_tooling_add_build_dependency owner tool phase)
    cmake_parse_arguments(ARG "" "" "FILES;TARGETS" ${ARGN})
    set_property(GLOBAL APPEND PROPERTY _CMAKE_TOOLING_BUILD_TARGETS "${owner}" ${ARG_TARGETS})
    set_property(GLOBAL APPEND PROPERTY _CMAKE_TOOLING_BUILD_${phase}_TARGETS "${tool}")
    foreach(_file IN LISTS ARG_FILES)
        get_filename_component(_absolute "${_file}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
        set_property(GLOBAL APPEND PROPERTY _CMAKE_TOOLING_BUILD_FILES "${_absolute}")
    endforeach()

    get_property(_scheduled GLOBAL PROPERTY _CMAKE_TOOLING_BUILD_SCHEDULED)
    if (NOT _scheduled)
        set_property(GLOBAL PROPERTY _CMAKE_TOOLING_BUILD_SCHEDULED TRUE)
        cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}"
                CALL _cmake_tooling_finalize_build_dependencies)
    endif ()
endfunction()

function(_cmake_tooling_finalize_build_dependencies)
    get_property(_targets GLOBAL PROPERTY _CMAKE_TOOLING_BUILD_TARGETS)
    get_property(_files GLOBAL PROPERTY _CMAKE_TOOLING_BUILD_FILES)
    get_property(_annotators GLOBAL PROPERTY _CMAKE_TOOLING_BUILD_annotate_TARGETS)
    get_property(_formatters GLOBAL PROPERTY _CMAKE_TOOLING_BUILD_format_TARGETS)
    get_property(_analyzers GLOBAL PROPERTY _CMAKE_TOOLING_BUILD_analyze_TARGETS)
    list(REMOVE_DUPLICATES _targets)
    list(REMOVE_DUPLICATES _files)

    # All annotation finishes before formatting, regardless of registration order.
    if (_annotators)
        foreach(_formatter IN LISTS _formatters)
            add_dependencies(${_formatter} ${_annotators})
        endforeach()
    endif ()

    # Analyze the prepared files, never concurrently with tools that rewrite them.
    if (_annotators OR _formatters)
        foreach(_analyzer IN LISTS _analyzers)
            add_dependencies(${_analyzer} ${_annotators} ${_formatters})
        endforeach()
    endif ()

    set(_directory "${CMAKE_BINARY_DIR}/cmake-tooling")
    set(_file_list "${_directory}/source-preparation-files.cmake")
    set(_stamp "${_directory}/source-preparation.stamp")
    file(GENERATE OUTPUT "${_file_list}"
            CONTENT "set(CMAKE_TOOLING_PREPARATION_FILES [==[${_files}]==])\n")

    add_custom_target(tooling-prepare ALL
            COMMAND "${CMAKE_COMMAND}"
                    "-DCMAKE_TOOLING_PREPARATION_FILE_LIST=${_file_list}"
                    "-DCMAKE_TOOLING_PREPARATION_STAMP=${_stamp}"
                    -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../scripts/source-preparation-stamp.cmake"
            BYPRODUCTS "${_stamp}"
            DEPENDS ${_annotators} ${_formatters} ${_analyzers}
            COMMENT "Recording prepared source content"
            VERBATIM)

    foreach(_target IN LISTS _targets)
        if (NOT TARGET ${_target})
            message(FATAL_ERROR "Tooling build dependency requires an existing target: ${_target}")
        endif ()
        add_dependencies(${_target} tooling-prepare)
        get_target_property(_sources ${_target} SOURCES)
        if (NOT _sources)
            set(_sources "")
        endif ()
        # Explicit object dependencies let Ninja notice modifications in this build.
        # Only the build-directory stamp is a byproduct: clean must preserve sources.
        set_property(SOURCE ${_sources} ${_files} TARGET_DIRECTORY ${_target}
                APPEND PROPERTY OBJECT_DEPENDS "${_stamp}")
    endforeach()
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
