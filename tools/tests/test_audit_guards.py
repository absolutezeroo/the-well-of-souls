"""Host-side regressions for the test runner and a real short filesystem write.

Run with GODOT=/path/to/godot python3 -m unittest discover -s tools/tests.
The filesystem failure uses Linux RLIMIT_FSIZE in a temporary, isolated Godot project.
"""
import importlib.util
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import unittest

try:
    import resource
except ImportError:
    resource = None

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("well_test_runner", ROOT / "tools/run_tests.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class EngineErrors(unittest.TestCase):
    def test_script_and_unexpected_engine_errors_fail(self):
        for line in (
            "SCRIPT ERROR: Invalid call. Nonexistent 'float' constructor.",
            "ERROR: Failed loading resource: res://missing.tres.",
            "ERROR: Parse JSON failed. Error at line 0: Unexpected EOF",
        ):
            with self.subTest(line=line):
                self.assertTrue(runner.unexpected_engine_error(line))

    def test_only_documented_shutdown_diagnostics_are_exempt(self):
        for line in (
            "ERROR: 1 resources still in use at exit (run with --verbose for details).",
            "ERROR: 2 RID allocations of type 'DummyShader' were leaked at exit.",
            "[test] game.example: 2 checks, 0 failed, 0.1 s",
        ):
            with self.subTest(line=line):
                self.assertFalse(runner.unexpected_engine_error(line))
        self.assertTrue(runner.unexpected_engine_error("ERROR: a resource was leaked during gameplay"))


class Portability(unittest.TestCase):
    def test_the_runner_loads_without_the_unix_resource_module(self):
        # Windows has no `resource`: the runner must still start (it only loses the CPU time).
        import sys
        saved = sys.modules.get("resource")
        sys.modules["resource"] = None  # makes `import resource` raise ImportError
        try:
            probe_spec = importlib.util.spec_from_file_location("well_test_runner_windows", ROOT / "tools/run_tests.py")
            probe = importlib.util.module_from_spec(probe_spec)
            probe_spec.loader.exec_module(probe)
            self.assertIsNone(probe.resource)
        finally:
            if saved is None:
                del sys.modules["resource"]
            else:
                sys.modules["resource"] = saved


@unittest.skipUnless(resource is not None and hasattr(resource, "prlimit"), "requires Linux prlimit")
class ShortWrite(unittest.TestCase):
    def test_a_short_write_preserves_the_previous_save(self):
        godot = runner.find_godot(None)
        with tempfile.TemporaryDirectory(prefix="well_short_write_") as directory:
            folder = Path(directory)
            (folder / "project.godot").write_text('config_version=5\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
            (folder / "safe_file.gd").write_text((ROOT / "src/core/safe_file.gd").read_text())
            (folder / "probe.gd").write_text('''extends SceneTree
const Save = preload("res://safe_file.gd")
func _initialize() -> void:
    var path := "res://profile.json"
    if not Save.write_json(path, {"souls": 100}):
        quit(2)
        return
    print("READY_FOR_LIMIT")
    await create_timer(0.3).timeout
    var accepted := Save.write_json(path, {"souls": 999, "payload": "x".repeat(16000)})
    var kept: Variant = Save.read_json(path)
    var good: bool = not accepted and kept is Dictionary and kept.souls == 100 and not FileAccess.file_exists(path + ".tmp")
    print("SHORT_WRITE_SAFE=", good)
    quit(0 if good else 1)
''')
            process = subprocess.Popen(
                [godot, "--headless", "--path", directory, "--log-file", str(folder / "engine.log"), "--script", "res://probe.gd"],
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                env=dict(os.environ, XDG_DATA_HOME=str(folder / "user")),
                preexec_fn=lambda: signal.signal(signal.SIGXFSZ, signal.SIG_IGN),
            )
            output = []
            try:
                for line in process.stdout:
                    output.append(line)
                    if "READY_FOR_LIMIT" in line:
                        resource.prlimit(process.pid, resource.RLIMIT_FSIZE, (4096, 4096))
                        break
                tail, _ = process.communicate(timeout=20)
                output.append(tail)
                self.assertEqual(process.returncode, 0, "".join(output))
                self.assertIn("SHORT_WRITE_SAFE=true", "".join(output))
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait()


if __name__ == "__main__":
    unittest.main()
