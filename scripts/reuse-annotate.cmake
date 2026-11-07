cmake_minimum_required(VERSION 3.28.3)

# Forward the executable and arguments following `cmake -P <script> --`.
set(_command)
math(EXPR _last_arg "${CMAKE_ARGC} - 1")
foreach (_index RANGE 4 ${_last_arg})
    list(APPEND _command "${CMAKE_ARGV${_index}}")
endforeach ()

# Keep stderr visible and preserve failure status; filter only skip notices.
execute_process(COMMAND ${_command}
        OUTPUT_VARIABLE _output
        RESULT_VARIABLE _result)
string(REGEX REPLACE "(^|\n)Skipped file '[^\n]*' already containing REUSE information(\r?\n|$)"
        "\\1" _output "${_output}")
if (NOT _output STREQUAL "")
    execute_process(COMMAND "${CMAKE_COMMAND}" -E echo_append "${_output}")
endif ()
if (NOT "${_result}" STREQUAL "0")
    message(FATAL_ERROR "REUSE annotation failed: ${_result}")
endif ()
