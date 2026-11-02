"""Compile and exercise small consumers, including real sanitizer/LLVM reports."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]
GCC = shutil.which("gcc")
GXX = shutil.which("g++")
CLANG = shutil.which("clang")
CLANGXX = shutil.which("clang++")


class InstrumentationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="cmake instrumentation ")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / "source with spaces"
        self.source.mkdir()
        self.build = self.root / "build with spaces"
        (self.source / "library.c").write_text(
            "int sample(int x) { if (x > 0) return x + 1; return -x; }\n")
        (self.source / "main.cpp").write_text('''
#include <limits>
#include <cstring>
extern "C" int sample(int);
int main(int argc, char **argv) {
    if (argc > 1 && std::strcmp(argv[1], "overflow") == 0) {
        volatile int x = std::numeric_limits<int>::max();
        return x + 1;
    }
    return sample(argc > 1 ? -2 : 1) == 2 ? 0 : 1;
}
''')
        (self.source / "plain.cpp").write_text("int main() { return 0; }\n")

    def run_command(self, *args, success=True, env=None):
        result = subprocess.run([str(arg) for arg in args], text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                env=dict(os.environ) | (env or {}))
        self.assertEqual(result.returncode == 0, success, result.stdout)
        return result.stdout

    def configure(self, registration, compiler="gcc", definitions=(),
                  generator="Ninja", success=True):
        cc, cxx = (GCC, GXX) if compiler == "gcc" else (CLANG, CLANGXX)
        if not cc or not cxx:
            self.skipTest(f"{compiler} C/C++ compilers are not installed")
        (self.source / "CMakeLists.txt").write_text(f'''
cmake_minimum_required(VERSION 3.28.3)
project(consumer LANGUAGES C CXX)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
enable_testing()
add_subdirectory("{REPO}" tooling)
add_library(sample STATIC library.c)
add_executable(app main.cpp)
target_link_libraries(app PRIVATE sample)
add_executable(unrelated plain.cpp)
add_test(NAME positive COMMAND app)
add_test(NAME negative COMMAND app negative)
{registration}
''')
        return self.run_command("cmake", "-S", self.source, "-B", self.build,
                                "-G", generator, f"-DCMAKE_C_COMPILER={cc}",
                                f"-DCMAKE_CXX_COMPILER={cxx}",
                                "-DCMAKE_BUILD_TYPE=Debug", *definitions,
                                success=success)

    def build_target(self, target=None, success=True, env=None, config=None):
        args = ["cmake", "--build", self.build]
        if target:
            args += ["--target", target]
        if config:
            args += ["--config", config]
        return self.run_command(*args, success=success, env=env)

    def commands(self):
        return {Path(item["file"]).name: item["command"] for item in
                json.loads((self.build / "compile_commands.json").read_text())}

    def mock_tool(self, name, body=""):
        path = self.root / name
        path.write_text("#!/usr/bin/env python3\nimport json, os, pathlib, sys\n"
                        "with open(os.environ['TOOL_LOG'], 'a') as stream:\n"
                        "    stream.write(json.dumps(sys.argv[1:]) + '\\n')\n"
                        "if os.environ.get('TOOL_EXIT'): sys.exit(1)\n" + body)
        path.chmod(0o755)
        return path

    def test_sanitizer_runtime_and_scope(self):
        self.configure('''
enable_target_sanitizers(TARGET sample SANITIZERS undefined)
enable_target_sanitizers(TARGET app SANITIZERS undefined)
enable_target_sanitizers(TARGET app SANITIZERS undefined undefined)
''')
        self.build_target()
        commands = self.commands()
        for source in ("library.c", "main.cpp"):
            self.assertIn("-fsanitize=undefined", commands[source])
            self.assertIn("-fno-sanitize-recover=undefined", commands[source])
        self.assertNotIn("-fsanitize", commands["plain.cpp"])
        self.run_command(self.build / "app")
        output = self.run_command(self.build / "app", "overflow", success=False)
        self.assertIn("runtime error", output)

    def test_sanitizer_static_library_link_runtime(self):
        self.configure("enable_target_sanitizers(TARGET sample SANITIZERS undefined)")
        self.build_target("app")
        self.assertNotIn("-fsanitize", self.commands()["main.cpp"])
        self.run_command(self.build / "app")

    def test_clang_default_sanitizers(self):
        self.configure("enable_target_sanitizers(TARGET app)", compiler="clang")
        self.build_target("app")
        self.assertIn("-fsanitize=address,undefined", self.commands()["main.cpp"])
        # LeakSanitizer cannot inspect processes under some sandbox/ptrace setups.
        # This check exercises ASan/UBSan; it does not test leak detection.
        self.run_command(self.build / "app", env={"ASAN_OPTIONS": "detect_leaks=0"})

    def test_thread_sanitizer_build(self):
        self.configure("enable_target_sanitizers(TARGET app SANITIZERS thread)")
        self.build_target("app")
        self.assertIn("-fsanitize=thread", self.commands()["main.cpp"])
        # Running TSan requires platform virtual-memory/ASLR support that a
        # sandbox may not provide. Compilation/linking still checks the runtime.

    def test_coverage_static_library_link_runtime(self):
        self.configure('''
enable_target_coverage(TARGET sample)
enable_target_coverage(TARGET sample)
''')
        self.build_target("app")
        self.assertIn("--coverage", self.commands()["library.c"])
        self.assertNotIn("--coverage", self.commands()["main.cpp"])
        self.run_command(self.build / "app")
        self.assertTrue(list(self.build.rglob("library.c.gcda")))

    def test_invalid_instrumentation(self):
        cases = [
            ("enable_target_sanitizers(TARGET absent)", "existing target"),
            ("enable_target_sanitizers(TARGET app SANITIZERS address thread)",
             "cannot be combined"),
            ("enable_target_sanitizers(TARGET app SANITIZERS typo)", "Unsupported sanitizer"),
            ("enable_target_sanitizers(TARGET app SANITIZERS)", "requires TARGET"),
            ("enable_target_sanitizers(TARGET app SANITIZERS undefined)\n"
             "enable_target_sanitizers(TARGET app SANITIZERS address)", "differently"),
            ("add_library(alias ALIAS sample)\nenable_target_coverage(TARGET alias)",
             "locally built"),
            ("add_custom_target(custom)\nenable_target_sanitizers(TARGET custom)",
             "locally built"),
            ("add_library(imported STATIC IMPORTED)\nenable_target_coverage(TARGET imported)",
             "locally built"),
            ("set(CMAKE_CXX_COMPILER_ID Unsupported)\nenable_target_sanitizers(TARGET app)",
             "requires GCC or Clang"),
            ("set(CMAKE_CXX_COMPILER_FRONTEND_VARIANT MSVC)\nenable_target_coverage(TARGET app)",
             "GNU-style driver"),
            ("add_coverage_target(TARGET coverage TARGETS sample)", "test executable"),
            ("add_coverage_target(TARGET coverage TARGETS absent)", "existing target"),
            ("enable_target_coverage(TARGET app TYPO)", "requires TARGET"),
            ("set(CMAKE_CXX_COMPILER_ID Clang)\n"
             "add_coverage_target(TARGET coverage TARGETS app)", "same compiler family"),
            ("set(CMAKE_CXX_FLAGS -fsanitize=not-a-sanitizer)\n"
             "enable_target_sanitizers(TARGET app SANITIZERS undefined)",
             "instrumentation is unavailable"),
        ]
        for registration, message in cases:
            with self.subTest(registration=registration):
                output = self.configure(registration, success=False)
                self.assertIn(message, output)

    def test_gcc_coverage_pipeline(self):
        mock = self.mock_tool("gcovr mock")
        self.configure('''
add_coverage_target(TARGET coverage TARGETS sample app
    TEST_REGEX "^positive$" EXCLUDE "other path/.*"
    OUTPUT_DIRECTORY "report with spaces" CTEST_ARGS --parallel 2)
''', definitions=[f"-DGCOVR_EXECUTABLE={mock}"])
        self.build_target()
        log = self.root / "calls.jsonl"
        self.assertFalse(log.exists(), "Reporting must be on demand")
        # Put stale counters beside actual objects and verify they are removed.
        stale = self.build / "stale.gcda"
        stale.write_text("old run")
        env = {"TOOL_LOG": str(log)}
        output = self.build_target("coverage", env=env)
        self.assertIn("1/1 Test", output)
        self.assertFalse(stale.exists())
        self.assertTrue(list(self.build.rglob("library.c.gcda")))
        commands = self.commands()
        self.assertIn("--coverage", commands["library.c"])
        self.assertIn("--coverage", commands["main.cpp"])
        self.assertNotIn("--coverage", commands["plain.cpp"])
        calls = [json.loads(line) for line in log.read_text().splitlines()]
        self.assertEqual(len(calls), 1)
        self.assertIn(str(self.build / "report with spaces/Debug/index.html"), calls[0])
        self.assertIn("(^|/)(vendor|_deps)/", calls[0])
        self.assertIn("other path/.*", calls[0])
        self.build_target("coverage", success=False, env=env | {"TOOL_EXIT": "1"})

    def test_coverage_missing_tools(self):
        registration = '''
function(find_program output)
    set(${output} "${output}-NOTFOUND" PARENT_SCOPE)
endfunction()
add_coverage_target(TARGET coverage TARGETS sample app)
'''
        self.configure(registration)
        self.assertNotIn("--coverage", self.commands()["main.cpp"])
        self.assertNotIn("coverage:", self.build_target("help"))
        output = self.configure(registration, definitions=["-DCMAKE_TOOLING_STRICT=ON"],
                                success=False)
        self.assertIn("Required tooling executable not found: gcovr", output)

    def test_llvm_missing_tools(self):
        registration = '''
function(find_program output)
    set(${output} "${output}-NOTFOUND" PARENT_SCOPE)
endfunction()
add_coverage_target(TARGET coverage TARGETS sample app)
'''
        self.configure(registration, compiler="clang")
        self.assertNotIn("-fprofile-instr-generate", self.commands()["main.cpp"])
        self.assertNotIn("coverage:", self.build_target("help"))
        output = self.configure(registration, compiler="clang",
                                definitions=["-DCMAKE_TOOLING_STRICT=ON"], success=False)
        self.assertIn("Required tooling executable not found: llvm-cov", output)

    def test_failed_tests_stop_coverage(self):
        mock = self.mock_tool("gcovr mock")
        self.configure('''
add_test(NAME failure COMMAND "${CMAKE_COMMAND}" -E false)
add_coverage_target(TARGET coverage TARGETS sample app)
''', definitions=[f"-DGCOVR_EXECUTABLE={mock}"])
        log = self.root / "calls.jsonl"
        self.build_target("coverage", success=False, env={"TOOL_LOG": str(log)})
        self.assertFalse(log.exists(), "Do not report after failed tests")

    def test_no_matching_tests_fail_coverage(self):
        mock = self.mock_tool("gcovr mock")
        self.configure('''
add_coverage_target(TARGET coverage TARGETS app TEST_REGEX "^nonexistent$")
''', definitions=[f"-DGCOVR_EXECUTABLE={mock}"])
        output = self.build_target("coverage", success=False)
        self.assertIn("No tests were found", output)

    @unittest.skipUnless(shutil.which("llvm-cov") and shutil.which("llvm-profdata"),
                         "LLVM reporting tools are not installed")
    def test_real_llvm_coverage_multiconfig(self):
        vendor = self.source / "vendor"
        vendor.mkdir()
        (vendor / "vendor.cpp").write_text("int vendored_function() { return 1; }\n")
        self.configure('''
target_sources(app PRIVATE vendor/vendor.cpp)
add_coverage_target(TARGET coverage TARGETS sample app EXCLUDE "main\\\\.cpp$")
''', compiler="clang", generator="Ninja Multi-Config")
        for config in ("Debug", "Release"):
            with self.subTest(config=config):
                self.build_target("coverage", config=config)
                output = self.build / "coverage/coverage" / config
                self.assertTrue((output / "index.html").is_file())
                lcov = (output / "coverage.lcov").read_text()
                self.assertIn("library.c", lcov)
                self.assertNotIn("main.cpp", lcov)
                self.assertNotIn("vendor.cpp", lcov)
                stale = output / "profile-stale.profraw"
                stale.write_text("invalid profile")
                self.build_target("coverage", config=config)
                self.assertFalse(stale.exists())

    @unittest.skipUnless(shutil.which("llvm-cov") and shutil.which("llvm-profdata")
                         and shutil.which("clang-scan-deps"),
                         "LLVM reporting and module scanning tools are not installed")
    def test_clang_cpp_modules_with_sanitizers_and_coverage(self):
        (self.source / "example.cppm").write_text('''
export module example;
export int module_answer(int x) { return x > 0 ? x + 1 : -x; }
''')
        (self.source / "main.cpp").write_text('''
import example;
int main(int argc, char **) { return module_answer(argc > 1 ? -2 : 1) == 2 ? 0 : 1; }
''')
        self.configure('''
add_library(module_lib STATIC)
target_sources(module_lib PUBLIC FILE_SET CXX_MODULES FILES example.cppm)
target_compile_features(module_lib PUBLIC cxx_std_20)
target_link_libraries(app PRIVATE module_lib)
enable_target_sanitizers(TARGET module_lib SANITIZERS undefined)
enable_target_sanitizers(TARGET app SANITIZERS undefined)
add_coverage_target(TARGET coverage TARGETS module_lib app)
''', compiler="clang")
        self.build_target("coverage")
        lcov = (self.build / "coverage/coverage/Debug/coverage.lcov").read_text()
        self.assertIn("example.cppm", lcov)

    @unittest.skipUnless(shutil.which("gcovr"), "gcovr is not installed")
    def test_real_gcovr_report(self):
        self.configure("add_coverage_target(TARGET coverage TARGETS sample app)")
        self.build_target("coverage")
        output = self.build / "coverage/coverage/Debug"
        self.assertTrue((output / "index.html").is_file())
        self.assertIn("library.c", (output / "coverage.xml").read_text())


if __name__ == "__main__":
    unittest.main()
