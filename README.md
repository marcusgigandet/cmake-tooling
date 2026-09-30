# cmake-tooling

Reusable CMake tooling modules for code-quality and license-compliance targets.
Intended to be consumed as a git submodule via `add_subdirectory()`.

## Usage

```cmake
add_subdirectory(<path-to-cmake-tooling>)
```

All modules under `modules/` are included automatically. To make a build work
without the submodule checked out, guard the call and provide no-op fallbacks:

```cmake
if (EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/vendor/cmake-tooling/CMakeLists.txt)
    add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/vendor/cmake-tooling)
else ()
    message(STATUS "cmake-tooling submodule not found, tooling targets are disabled.")
endif ()
```

## Modules

| Module                         | Function                    | Description                                                                           |
| ------------------------------ | --------------------------- | ------------------------------------------------------------------------------------- |
| `modules/clang-format.cmake`   | `add_code_format_target()`  | Adds a `clang-format` target as a dependency of the given target.                     |
| `modules/reuse-lint.cmake`     | `add_reuse_lint_target()`   | Adds a [REUSE](https://reuse.software) lint target to verify SPDX license compliance. |
| `modules/reuse-annotate.cmake` | `add_reuse_header_target()` | Adds a target that annotates files with REUSE-compliant SPDX license headers.         |

Adding a new module is a matter of dropping a `*.cmake` file into `modules/`;
it is picked up automatically.

## License

MIT. See [LICENSE](LICENSE).
