include_guard(GLOBAL)
include("${CMAKE_CURRENT_LIST_DIR}/tooling-common.cmake")
include("${CMAKE_CURRENT_LIST_DIR}/instrumentation-common.cmake")

function(_cmake_tooling_coverage_backend output)
    _cmake_tooling_instrumentation_languages(_languages)
    set(_backend "")
    foreach(_language IN LISTS _languages)
        if (CMAKE_${_language}_COMPILER_ID STREQUAL "GNU")
            set(_current GCOV)
        else ()
            set(_current LLVM)
        endif ()
        if (_backend AND NOT _backend STREQUAL _current)
            message(FATAL_ERROR "Coverage requires C and CXX compilers from the same compiler family")
        endif ()
        set(_backend "${_current}")
    endforeach()
    set(${output} "${_backend}" PARENT_SCOPE)
endfunction()

#[[
enable_target_coverage(TARGET target)

Instrument an existing C/C++ target with GCC gcov or Clang source coverage.
Compile flags are private; runtime link options propagate to library consumers.
Does not discover reporting tools or create a report target.
]]
function(enable_target_coverage)
    cmake_parse_arguments(ARG "" "TARGET" "" ${ARGN})
    if (NOT ARG_TARGET OR ARG_UNPARSED_ARGUMENTS OR ARG_KEYWORDS_MISSING_VALUES)
        message(FATAL_ERROR "enable_target_coverage requires TARGET")
    endif ()
    _cmake_tooling_instrumentation_target("${ARG_TARGET}")
    _cmake_tooling_coverage_backend(_backend)
    get_target_property(_previous "${ARG_TARGET}" _CMAKE_TOOLING_COVERAGE)
    if (_previous)
        return()
    endif ()
    if (_backend STREQUAL "GCOV")
        set(_compile_options --coverage)
        set(_link_options --coverage)
    else ()
        set(_compile_options -fprofile-instr-generate -fcoverage-mapping)
        set(_link_options -fprofile-instr-generate)
    endif ()
    _cmake_tooling_instrumentation_languages(_languages)
    foreach(_language IN LISTS _languages)
        _cmake_tooling_check_instrumentation("${_language}" "${_compile_options}" "${_link_options}")
    endforeach()
    _cmake_tooling_apply_instrumentation("${ARG_TARGET}" "${_compile_options}" "${_link_options}")
    set_property(TARGET "${ARG_TARGET}" PROPERTY _CMAKE_TOOLING_COVERAGE "${_backend}")
endfunction()

#[[
add_coverage_target(TARGET name TARGETS library test_executable ...
    [SOURCE_DIRECTORY dir] [OUTPUT_DIRECTORY dir] [TEST_REGEX regex]
    [EXCLUDE regex ...] [CTEST_ARGS args ...])

Instrument and build TARGETS, run top-level CTest, then write an HTML report.
TARGETS must contain an executable and every project library to instrument.
SOURCE_DIRECTORY defaults to the calling source directory; OUTPUT_DIRECTORY to
<calling-binary-dir>/coverage/<name>/<config>. Relative directories use the
calling source/binary directory respectively. Vendor and _deps paths are excluded
by default; EXCLUDE adds regexes. TEST_REGEX selects CTest tests, otherwise all run.
Requires top-level enable_testing(). Missing report tools skip registration and
instrumentation unless CMAKE_TOOLING_STRICT is ON. Report targets are on demand,
outside tooling-check. Use a dedicated build tree and run reports serially.
]]
function(add_coverage_target)
    cmake_parse_arguments(ARG "" "TARGET;SOURCE_DIRECTORY;OUTPUT_DIRECTORY;TEST_REGEX"
            "TARGETS;EXCLUDE;CTEST_ARGS" ${ARGN})
    if (NOT ARG_TARGET OR NOT ARG_TARGETS OR ARG_UNPARSED_ARGUMENTS OR ARG_KEYWORDS_MISSING_VALUES)
        message(FATAL_ERROR "add_coverage_target requires TARGET and TARGETS")
    endif ()
    if (TARGET "${ARG_TARGET}")
        message(FATAL_ERROR "Coverage target already exists: ${ARG_TARGET}")
    endif ()
    _cmake_tooling_coverage_backend(_backend)
    set(_objects)
    set(_has_executable FALSE)
    foreach(_target IN LISTS ARG_TARGETS)
        _cmake_tooling_instrumentation_target("${_target}")
        get_target_property(_type "${_target}" TYPE)
        if (_type STREQUAL "EXECUTABLE")
            set(_has_executable TRUE)
        endif ()
        if (_type MATCHES "^(EXECUTABLE|SHARED_LIBRARY|MODULE_LIBRARY)$")
            list(APPEND _objects "$<TARGET_FILE:${_target}>")
        endif ()
    endforeach()
    if (NOT _has_executable)
        message(FATAL_ERROR "Coverage TARGETS must include at least one test executable")
    endif ()

    if (_backend STREQUAL "LLVM")
        _cmake_tooling_find(LLVM_COV_EXECUTABLE llvm-cov)
        _cmake_tooling_find(LLVM_PROFDATA_EXECUTABLE llvm-profdata)
        if (NOT LLVM_COV_EXECUTABLE OR NOT LLVM_PROFDATA_EXECUTABLE)
            return()
        endif ()
    else ()
        _cmake_tooling_find(GCOVR_EXECUTABLE gcovr)
        if (NOT GCOVR_EXECUTABLE)
            return()
        endif ()
    endif ()
    foreach(_target IN LISTS ARG_TARGETS)
        enable_target_coverage(TARGET "${_target}")
    endforeach()

    if (NOT ARG_SOURCE_DIRECTORY)
        set(ARG_SOURCE_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}")
    endif ()
    get_filename_component(_source "${ARG_SOURCE_DIRECTORY}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_SOURCE_DIR}")
    if (NOT ARG_OUTPUT_DIRECTORY)
        set(ARG_OUTPUT_DIRECTORY "coverage/${ARG_TARGET}")
    endif ()
    get_filename_component(_output "${ARG_OUTPUT_DIRECTORY}" ABSOLUTE BASE_DIR "${CMAKE_CURRENT_BINARY_DIR}")
    string(APPEND _output "/$<CONFIG>")
    set(_build "${CMAKE_BINARY_DIR}")
    set(_ctest "${CMAKE_CTEST_COMMAND}")
    set(_config "$<CONFIG>")
    set(_ctest_args --output-on-failure --no-tests=error)
    if (DEFINED ARG_TEST_REGEX)
        list(APPEND _ctest_args -R "${ARG_TEST_REGEX}")
    endif ()
    list(APPEND _ctest_args ${ARG_CTEST_ARGS})
    set(_exclude "(^|/)(vendor|_deps)/" ${ARG_EXCLUDE})
    # Each report/configuration has its own generated settings and LLVM profiles.
    set(_settings "")
    foreach(_variable IN ITEMS _backend _objects _source _output _build _ctest _config
            _ctest_args _exclude LLVM_COV_EXECUTABLE LLVM_PROFDATA_EXECUTABLE GCOVR_EXECUTABLE)
        string(APPEND _settings "set(${_variable} [==[${${_variable}}]==])\n")
    endforeach()
    set(_settings_file "${CMAKE_CURRENT_BINARY_DIR}/cmake-tooling/${ARG_TARGET}/$<CONFIG>/coverage.cmake")
    file(GENERATE OUTPUT "${_settings_file}" CONTENT "${_settings}")
    add_custom_target("${ARG_TARGET}"
            COMMAND "${CMAKE_COMMAND}" "-DCMAKE_TOOLING_COVERAGE_SETTINGS=${_settings_file}"
                    -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../scripts/coverage-report.cmake"
            DEPENDS ${ARG_TARGETS}
            COMMENT "Running tests and collecting ${_backend} coverage"
            USES_TERMINAL VERBATIM)
endfunction()
