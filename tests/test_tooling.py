"""Integration checks: python3 -m unittest discover -s tests -v."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

REPO = Path(__file__).resolve().parents[1]


class ToolingTests(unittest.TestCase):
    def test_consumer(self):
        with tempfile.TemporaryDirectory(prefix="cmake tooling ") as temporary:
            root = Path(temporary)
            source = root / "source"
            source.mkdir()
            log = root / "calls.jsonl"
            mock = root / "mock tool"
            mock.write_text(
                "#!/usr/bin/env python3\n"
                "import json, os, sys\n"
                "with open(os.environ['TOOL_LOG'], 'a') as f:\n"
                "    f.write(json.dumps(sys.argv[1:]) + '\\n')\n"
                "sys.exit(int(os.environ.get('TOOL_EXIT', '0')))\n"
            )
            mock.chmod(0o755)
            (source / "file with spaces.cpp").write_text("// untouched\n")
            (source / "CMakeLists.txt").write_text(f'''
cmake_minimum_required(VERSION 3.28.3)
project(consumer LANGUAGES NONE)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
add_subdirectory("{REPO}" tooling)
add_custom_target(app)
if (TEST_MISSING_TOOLS)
    function(find_program output)
        set(${{output}} "${{output}}-NOTFOUND" PARENT_SCOPE)
    endfunction()
endif ()
add_code_format_target(TARGET app FILES "file with spaces.cpp")
add_clang_tidy_target(TARGET app FILES "${{CMAKE_CURRENT_SOURCE_DIR}}/file with spaces.cpp")
add_reuse_lint_target(TARGET app)
add_reuse_header_target(TARGET app LICENSE MIT USERS "First Author" "Second Author"
    FILES "file with spaces.cpp" FLAGS --year 2026)
add_cmake_format_target(TARGET app FILES CMakeLists.txt)
add_cmake_lint_target(TARGET app FILES CMakeLists.txt)
''')
            env = dict(os.environ, TOOL_LOG=str(log))

            def run(*args, success=True, extra_env=None):
                result = subprocess.run(args, env=env | (extra_env or {}),
                                        text=True, stdout=subprocess.PIPE,
                                        stderr=subprocess.STDOUT)
                self.assertEqual(result.returncode == 0, success, result.stdout)
                return result.stdout

            definitions = [f"-D{name}_EXECUTABLE={mock}" for name in
                           ("CLANG_FORMAT", "CLANG_TIDY", "REUSE", "CMAKE_FORMAT", "CMAKE_LINT")]
            build = root / "build"
            run("cmake", "-S", str(source), "-B", str(build), "-G", "Ninja",
                "-DCMAKE_TOOLING_STRICT=ON", *definitions)
            run("cmake", "--build", str(build))
            self.assertFalse(log.exists(), "Default build must not invoke tools")
            run("cmake", "--build", str(build), "--target", "tooling-check")
            calls = [json.loads(line) for line in log.read_text().splitlines()]
            self.assertEqual(len(calls), 5)
            self.assertIn(["--dry-run", "--Werror", "file with spaces.cpp"], calls)
            self.assertIn(["lint"], calls)
            self.assertTrue(any("--warnings-as-errors=*" in call for call in calls))
            self.assertFalse(any("-i" in call or "annotate" in call for call in calls))
            log.unlink()
            run("cmake", "--build", str(build), "--target", "tooling-fix")
            calls = [json.loads(line) for line in log.read_text().splitlines()]
            self.assertEqual(len(calls), 3)
            self.assertIn(["-i", "file with spaces.cpp"], calls)
            self.assertIn(["annotate", "--license", "MIT", "--copyright", "First Author",
                           "--copyright", "Second Author", "--skip-existing", "--year",
                           "2026", "file with spaces.cpp"], calls)
            for target in ("app-format-check", "app-reuse-lint", "app-clang-tidy",
                           "app-cmake-format-check", "app-cmake-lint", "tooling-check"):
                run("cmake", "--build", str(build), "--target", target,
                    success=False, extra_env={"TOOL_EXIT": "1"})

            # Force lookup failure without depending on installed tools.
            missing = root / "missing"
            args = ("cmake", "-S", str(source), "-B", str(missing), "-G", "Ninja",
                    f"-DCMAKE_MAKE_PROGRAM={shutil.which('ninja')}",
                    "-DTEST_MISSING_TOOLS=ON")
            run(*args)
            self.assertNotIn("tooling-check:", run("cmake", "--build", str(missing),
                                                    "--target", "help"))
            run(*args, "-DCMAKE_TOOLING_STRICT=ON", success=False)
            self.assertEqual((source / "file with spaces.cpp").read_text(), "// untouched\n")


if __name__ == "__main__":
    unittest.main()
