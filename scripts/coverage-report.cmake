cmake_minimum_required(VERSION 3.28.3)
include("${CMAKE_TOOLING_COVERAGE_SETTINGS}")
file(MAKE_DIRECTORY "${_output}")

if (_backend STREQUAL "LLVM")
    file(GLOB _old_profiles "${_output}/profile-*.profraw")
    if (_old_profiles)
        file(REMOVE ${_old_profiles})
    endif ()
    set(_environment "LLVM_PROFILE_FILE=${_output}/profile-%m-%p.profraw")
else ()
    # GCC writes counters beside object files. Clear old runs before testing;
    # .gcno mapping files are retained. This requires exclusive use of the tree.
    file(GLOB_RECURSE _old_profiles "${_build}/*.gcda")
    if (_old_profiles)
        file(REMOVE ${_old_profiles})
    endif ()
    set(_environment)
endif ()

execute_process(COMMAND "${CMAKE_COMMAND}" -E env ${_environment}
        "${_ctest}" -C "${_config}" ${_ctest_args}
        WORKING_DIRECTORY "${_build}" COMMAND_ERROR_IS_FATAL ANY)

if (_backend STREQUAL "LLVM")
    file(GLOB _profiles "${_output}/profile-*.profraw")
    if (NOT _profiles)
        message(FATAL_ERROR "Tests produced no LLVM coverage profiles")
    endif ()
    execute_process(COMMAND "${LLVM_PROFDATA_EXECUTABLE}" merge -sparse ${_profiles}
            -o "${_output}/coverage.profdata" COMMAND_ERROR_IS_FATAL ANY)
    set(_object_args)
    foreach(_object IN LISTS _objects)
        list(APPEND _object_args -object "${_object}")
    endforeach()
    list(JOIN _exclude "|" _exclude_regex)
    set(_report_args ${_object_args} "-instr-profile=${_output}/coverage.profdata"
            "-ignore-filename-regex=${_exclude_regex}")
    execute_process(COMMAND "${LLVM_COV_EXECUTABLE}" show ${_report_args}
            -format=html "-output-dir=${_output}"
            WORKING_DIRECTORY "${_source}" COMMAND_ERROR_IS_FATAL ANY)
    execute_process(COMMAND "${LLVM_COV_EXECUTABLE}" export ${_report_args} -format=lcov
            OUTPUT_FILE "${_output}/coverage.lcov"
            WORKING_DIRECTORY "${_source}" COMMAND_ERROR_IS_FATAL ANY)
    execute_process(COMMAND "${LLVM_COV_EXECUTABLE}" report ${_report_args}
            WORKING_DIRECTORY "${_source}" COMMAND_ERROR_IS_FATAL ANY)
else ()
    set(_exclude_args)
    foreach(_pattern IN LISTS _exclude)
        list(APPEND _exclude_args --exclude "${_pattern}")
    endforeach()
    execute_process(COMMAND "${GCOVR_EXECUTABLE}" --root "${_source}"
            --html-details "${_output}/index.html" --xml "${_output}/coverage.xml"
            --print-summary ${_exclude_args} "${_build}"
            WORKING_DIRECTORY "${_build}" COMMAND_ERROR_IS_FATAL ANY)
endif ()
message(STATUS "Coverage report: ${_output}/index.html")
