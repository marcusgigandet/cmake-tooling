# cmake-tooling

Reusable CMake tooling modules for code-quality and license-compliance targets.
Intended to be consumed as a git submodule via `add_subdirectory()`.

## Usage

```cmake
add_subdirectory(<path-to-cmake-tooling>)
```

All modules under `modules/` are included automatically. To make a build work
without the submodule checked out, guard the call:

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
| `modules/clang-format.cmake`   | `add_code_format_target()`  | Adds explicit format and format-check targets.                     |
| `modules/clang-tidy.cmake`     | `add_clang_tidy_target()`   | Adds an on-demand `clang-tidy` analysis target for the given files.                  |
| `modules/compile-commands.cmake` | `add_compile_commands_copy_target()` | Copies `compile_commands.json` after the selected target builds.       |
| `modules/reuse-lint.cmake`     | `add_reuse_lint_target()`   | Adds a [REUSE](https://reuse.software) lint target to verify SPDX license compliance. |
| `modules/reuse-annotate.cmake` | `add_reuse_header_target()` | Adds a target that annotates files with REUSE-compliant SPDX license headers.         |

| `modules/cmake-format.cmake` | `add_cmake_format_target()` | Adds CMake format and format-check targets. |
| `modules/cmake-format.cmake` | `add_cmake_lint_target()` | Adds a CMake lint target. |

## Checks and fixes

Tooling functions register explicit targets with two aggregates:

```sh
cmake --build build --target tooling-check
cmake --build build --target tooling-fix
```

`tooling-check` runs registered C++/CMake format checks, clang-tidy, CMake
lint, and REUSE lint. `tooling-fix` runs registered formatters and REUSE
annotation. Neither aggregate runs as part of the default build. Aggregates
are created when at least one corresponding tooling target is registered.
Only clang-tidy builds its associated compilation target first.

**Migration:** formatting, REUSE annotation, and REUSE lint are no longer
attached to consumer build targets. Invoke the explicit targets or aggregates.
Existing `<TARGET>-format`, `<TARGET>-clang-tidy`, `<TARGET>-reuse-lint`, and
`<TARGET>-reuse-headers` names remain available. Anonymous REUSE target names
now use a directory hash; use the aggregates or provide `TARGET` for stable names.

Missing executables skip the associated targets by default. Enable strict
mode in CI to require every tool requested through these functions:

```sh
cmake -S . -B build -DCMAKE_TOOLING_STRICT=ON
cmake --build build --target tooling-check
```

Failures from installed tools always propagate. Strict mode additionally passes
`--warnings-as-errors=*` to clang-tidy. The compilation database requirement
for clang-tidy still applies when that tool is available.

## Example registration

Call these from the consumer directory after including cmake-tooling:

```cmake
add_code_format_target(TARGET app FILES src/main.cpp)
add_reuse_lint_target(TARGET app)
add_reuse_header_target(
    TARGET app
    LICENSE MIT
    USERS "Example Contributors"
    FILES src/main.cpp
)
add_cmake_format_target(TARGET app FILES CMakeLists.txt cmake/options.cmake)
add_cmake_lint_target(TARGET app FILES CMakeLists.txt cmake/options.cmake)
```

Install `clang-format`, `clang-tidy`, and `reuse` as needed. CMake formatting
and linting use the `cmake-format` and `cmake-lint` executables from the
[`cmakelang`](https://cmake-format.readthedocs.io/en/latest/installation.html) Python package (`python -m pip install cmakelang`). Configuration
files are discovered by the tools using their normal behavior. File paths are
relative to the calling source directory unless absolute; quote paths containing
spaces. Choose a distinct `TARGET` prefix for each registration of a function.
`TARGET` is a naming prefix except for clang-tidy, which requires an existing
build target.

Adding a new module is a matter of dropping a `*.cmake` file into `modules/`;
it is picked up automatically.

## License

MIT. See [LICENSE](LICENSE).

## Testing

Run `python3 -m unittest discover -s tests -v` with CMake and Ninja installed.
The integration test uses mock executables to check registration, command
arguments, optional/required tools, failure propagation, and default-build behavior.
