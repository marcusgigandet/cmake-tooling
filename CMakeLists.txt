cmake_minimum_required(VERSION 3.28.3)
project(cmake-tooling LANGUAGES NONE)

# Include every tooling module so consumers get all functions after
# add_subdirectory(<path-to-cmake-tooling>).
file(GLOB _cmake_tooling_modules "${CMAKE_CURRENT_LIST_DIR}/modules/*.cmake")
foreach(_cmake_tooling_module IN LISTS _cmake_tooling_modules)
    include("${_cmake_tooling_module}")
endforeach()
