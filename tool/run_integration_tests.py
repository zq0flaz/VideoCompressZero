#!/usr/bin/env python3
"""Run the real Flutter plugin on an Android emulator or iOS simulator."""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
EXAMPLE = ROOT / "example"


def run(command, *, capture=False, timeout=180):
    return subprocess.run(command, check=True, text=True, timeout=timeout,
                          cwd=EXAMPLE, stdout=subprocess.PIPE if capture else None,
                          stderr=subprocess.PIPE if capture else None)


def best_effort(command, *, stdout=subprocess.DEVNULL, timeout=30):
    # Diagnostics and device cleanup must not hide the actual test exit code.
    try:
        subprocess.run(command, stdout=stdout, stderr=subprocess.STDOUT,
                       timeout=timeout, check=False)
    except (subprocess.SubprocessError, OSError) as error:
        print(f"Cleanup/diagnostic command failed: {error}", file=sys.stderr)


def android_tool(name, folder):
    suffix = ".exe" if os.name == "nt" else ""
    for variable in ("ANDROID_HOME", "ANDROID_SDK_ROOT"):
        if os.environ.get(variable):
            path = Path(os.environ[variable]) / folder / (name + suffix)
            if path.is_file():
                return str(path)
    found = shutil.which(name)
    if not found:
        raise RuntimeError(f"{name} not found; set ANDROID_HOME or add it to PATH")
    return found


def emulators(adb):
    return [line.split()[0] for line in run([adb, "devices"], capture=True).stdout.splitlines()
            if line.startswith("emulator-") and line.split()[1:] == ["device"]]


def android_device(args, reports, owned):
    adb = android_tool("adb", "platform-tools")
    devices = emulators(adb)
    if args.device:
        serial = args.device
    elif devices and not args.avd:
        serial = devices[0]
    else:
        emulator = android_tool("emulator", "emulator")
        avds = run([emulator, "-list-avds"], capture=True).stdout.splitlines()
        name = args.avd or next(iter(avds), None)
        if not name or name not in avds:
            raise RuntimeError("Create an Android AVD first, or pass --device <serial>")
        # An owned instance uses an explicit free port so another emulator is
        # never selected or stopped accidentally.
        listed = run([adb, "devices"], capture=True).stdout
        port = next(port for port in range(5554, 5586, 2)
                    if f"emulator-{port}" not in listed)
        serial = f"emulator-{port}"
        log = open(reports / "emulator.log", "w", encoding="utf-8")
        owned["emulator_log"] = log
        command = [emulator, "-avd", name, "-port", str(port),
                   "-no-snapshot-save", "-no-boot-anim"]
        if args.headless:
            command += ["-no-window", "-no-audio", "-gpu", "swiftshader_indirect"]
        owned["process"] = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
        owned["android"] = (adb, serial)
    deadline = time.monotonic() + 240
    while time.monotonic() < deadline:
        process = owned.get("process")
        if process and process.poll() is not None:
            raise RuntimeError(f"Emulator exited; see {reports / 'emulator.log'}")
        try:
            if run([adb, "-s", serial, "shell", "getprop", "sys.boot_completed"],
                   capture=True, timeout=10).stdout.strip() == "1":
                return serial, adb
        except (subprocess.SubprocessError, OSError):
            pass
        time.sleep(2)
    raise RuntimeError(f"Android device {serial} did not boot within 240 seconds")


def ios_device(args, reports, owned):
    if sys.platform != "darwin":
        raise RuntimeError("An iOS simulator requires macOS and Xcode")
    raw = run(["xcrun", "simctl", "list", "devices", "available", "--json"], capture=True).stdout
    (reports / "simulators.json").write_text(raw, encoding="utf-8")
    runtimes = json.loads(raw)["devices"]
    ordered = sorted(runtimes, key=lambda value: tuple(map(int, re.findall(r"\d+", value))), reverse=True)
    choices = [device for runtime in ordered if ".iOS-" in runtime
               for device in runtimes[runtime] if device.get("isAvailable", True)
               and device["name"].startswith("iPhone")]
    if args.device:
        device = next((device for device in choices if device["udid"] == args.device), None)
    else:
        device = next((device for device in choices if device["state"] == "Booted"),
                      next(iter(choices), None))
    if device is None:
        raise RuntimeError("No matching iPhone simulator; install an iOS runtime in Xcode")
    if device["state"] == "Shutdown":
        run(["xcrun", "simctl", "boot", device["udid"]])
        owned["ios"] = device["udid"]
    run(["xcrun", "simctl", "bootstatus", device["udid"], "-b"], timeout=240)
    return device["udid"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", required=True, choices=["android", "ios"])
    parser.add_argument("--device", help="Existing adb serial or iOS simulator UDID")
    parser.add_argument("--avd", help="Android AVD to launch (otherwise reuse or select one)")
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("--flutter", help="Flutter executable; defaults to local FVM SDK or PATH")
    parser.add_argument("--skip-pub-get", action="store_true")
    parser.add_argument("--timeout", type=int, default=1200, help="Test process timeout in seconds")
    args = parser.parse_args()
    suffix = ".bat" if os.name == "nt" else ""
    pinned = ROOT / ".fvm" / "flutter_sdk" / "bin" / ("flutter" + suffix)
    flutter = args.flutter or (str(pinned) if pinned.is_file() else shutil.which("flutter"))
    if not flutter:
        parser.error("Flutter not found; install the FVM SDK or pass --flutter <path>")
    reports = EXAMPLE / "build" / "integration_results" / args.platform
    reports.mkdir(parents=True, exist_ok=True)
    for name in ("flutter-test.log", "runner-error.log", "logcat.txt", "simulators.json",
                 "emulator.log", "result.json"):
        (reports / name).unlink(missing_ok=True)
    owned = {}
    serial = None
    adb = None
    code = 1
    started = time.monotonic()
    try:
        if not args.skip_pub_get:
            run([flutter, "pub", "get"], timeout=300)
        if args.platform == "android":
            serial, adb = android_device(args, reports, owned)
        else:
            serial = ios_device(args, reports, owned)
        command = [flutter, "test", "integration_test/video_compress_test.dart",
                   "--no-pub", "--reporter", "expanded", "-d", serial]
        print(f"Running {args.platform} integration tests on {serial}; reports: {reports}", flush=True)
        with open(reports / "flutter-test.log", "w", encoding="utf-8") as log:
            try:
                code = subprocess.run(command, cwd=EXAMPLE, stdout=log,
                                      stderr=subprocess.STDOUT, timeout=args.timeout).returncode
            except subprocess.TimeoutExpired:
                code = 124
                print("Flutter integration test process timed out", file=log)
        print((reports / "flutter-test.log").read_text(encoding="utf-8"), flush=True)
    except (RuntimeError, subprocess.SubprocessError, OSError) as error:
        print(f"Integration testing failed: {error}", file=sys.stderr)
        (reports / "runner-error.log").write_text(str(error), encoding="utf-8")
    finally:
        (reports / "result.json").write_text(json.dumps({
            "platform": args.platform, "device": serial, "exitCode": code,
            "elapsedSeconds": round(time.monotonic() - started, 2)
        }, indent=2), encoding="utf-8")
        # CI emulators contain only synthetic test data. Do not collect logs
        # from a developer's personal device when running locally.
        if os.environ.get("GITHUB_ACTIONS") == "true" and adb and serial and serial.startswith("emulator-"):
            with open(reports / "logcat.txt", "w", encoding="utf-8") as log:
                best_effort([adb, "-s", serial, "logcat", "-d"], stdout=log)
        if "android" in owned:
            best_effort([owned["android"][0], "-s", owned["android"][1], "emu", "kill"], timeout=20)
        if "process" in owned:
            try:
                owned["process"].wait(timeout=20)
            except subprocess.TimeoutExpired:
                owned["process"].kill()
                owned["process"].wait(timeout=10)
        if "emulator_log" in owned:
            owned["emulator_log"].close()
        if "ios" in owned:
            best_effort(["xcrun", "simctl", "shutdown", owned["ios"]])
    return code


if __name__ == "__main__":
    sys.exit(main())
