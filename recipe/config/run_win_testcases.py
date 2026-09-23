#!/usr/bin/env python3
"""
Run the code_aster testcases from the source tree against the just-installed
Windows build, mirroring the ``run_ctest`` step of ``build.sh`` on Linux
(same ctest label, known-failures exclusion, memory-per-slot throttling,
2 reruns of failed testcases, failure diagnostics).

Kept as a standalone script (like ``config/update_version.py``) instead of
inline batch, since batch's delayed-expansion/quoting rules make this class
of logic (dict/list handling, retries, text parsing) far more error-prone to
get right than in Python -- 'config/' is already where build.sh and build.bat
share such helpers.

Invokes '<PREFIX>\\python.exe -m run_aster.run_ctest_main' directly (rather
than the installed run_ctest.bat): this script itself runs under whichever
'python' build.bat's ambient PATH resolves to, and on Windows that is the
*build*-env python (waf's own python, here 3.13) which differs from the
*host*-env python (here 3.12, where code_aster's .pyd files actually live)
-- so a bare 'python' inside a subprocess would risk picking the wrong
interpreter. Addressing '<PREFIX>\\python.exe' explicitly removes that
ambiguity. Everything else (RUNASTER_ROOT, ASTER_DATADIR/ASTER_LIBDIR/etc.)
code_aster derives by itself from CONDA_PREFIX; see aster_env() below.

Env vars (all already set by rattler-build / build.bat):
    RECIPE_DIR         -- directory containing known_failures*.list
    SRC_DIR            -- source checkout (astest/ testcases live here)
    PREFIX             -- host prefix; <PREFIX>\\python.exe has code_aster
                          installed, <PREFIX>\\Library is where waf installed
                          the DLLs/run_ctest data files (--prefix=LIB_ROOT)
    CPU_COUNT          -- parallel ctest job count (falls back to os.cpu_count())
    ASTER_BUILD_TESTS  -- ctest label to run: "submit" (default),
                          "verification" (full suite) or "none" (skip)
"""

import ctypes
import os
import os.path as osp
import re
import subprocess
import sys


class MEMORYSTATUSEX(ctypes.Structure):
    _fields_ = [
        ("dwLength", ctypes.c_ulong),
        ("dwMemoryLoad", ctypes.c_ulong),
        ("ullTotalPhys", ctypes.c_ulonglong),
        ("ullAvailPhys", ctypes.c_ulonglong),
        ("ullTotalPageFile", ctypes.c_ulonglong),
        ("ullAvailPageFile", ctypes.c_ulonglong),
        ("ullTotalVirtual", ctypes.c_ulonglong),
        ("ullAvailVirtual", ctypes.c_ulonglong),
        ("ullAvailExtendedVirtual", ctypes.c_ulonglong),
    ]


def total_memory_mb():
    stat = MEMORYSTATUSEX()
    stat.dwLength = ctypes.sizeof(MEMORYSTATUSEX)
    ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(stat))
    return stat.ullTotalPhys // (1024 * 1024)


def build_known_failures(recipe_dir, src_dir):
    dest = osp.join(src_dir, "known_failures_win.list")
    with open(dest, "w", encoding="utf-8") as out:
        for name in ("known_failures.list", "known_failures_nompi.list", "known_failures_windows.list"):
            path = osp.join(recipe_dir, name)
            if osp.isfile(path):
                out.write(open(path, encoding="utf-8").read())
                out.write("\n")
    return dest


def aster_env(prefix):
    """Build the environment for '<prefix>\\python.exe -m run_aster...'.

    code_aster derives everything else (RUNASTER_ROOT via the fixed
    run_aster.base_params._set_root(), ASTER_DATADIR/ASTER_LIBDIR/etc. via
    msvc/c_entrypoints/entry_helpers.cxx's init_env()) from CONDA_PREFIX by
    itself -- this only needs to set that and extend PATH, exactly like a
    real 'conda activate' would.
    """
    library = osp.join(prefix, "Library")
    env = dict(os.environ)
    env["CONDA_PREFIX"] = prefix
    # numpy/scipy/medcoupling/mgis's own vendored DLLs rely on normal
    # PATH-based search to find Library\bin.
    env["PATH"] = os.pathsep.join([prefix, osp.join(library, "bin"), osp.join(prefix, "Scripts"), env.get("PATH", "")])
    return env


def run_ctest(host_python, ctest_args, env, cwd, rerun_failed=False):
    cmd = [host_python, "-m", "run_aster.run_ctest_main"] + ctest_args
    if rerun_failed:
        cmd.append("--rerun-failed")
    print("Running code_aster testcases:", " ".join(cmd))
    # cwd must NOT be SRC_DIR: 'python -m' prepends the working directory to
    # sys.path, and the source tree has its own run_aster/ package, which
    # would shadow the installed one. The source copy then resolves
    # RUNASTER_ROOT by walking up from its own location looking for "Lib",
    # never finds it, and silently falls through to the drive root --
    # every testcase then fails with
    #   Unable to find executable: C:/Library/share/aster/run_aster_for_ctest.bat
    # All paths passed to run_ctest_main are absolute, so any stable
    # directory works; PREFIX has no top-level run_aster/ to shadow with.
    return subprocess.run(cmd, env=env, cwd=cwd).returncode


def print_failure_diagnostics(resutest):
    failed_log = osp.join(resutest, "Testing", "Temporary", "LastTestsFailed.log")
    if not osp.isfile(failed_log):
        print(f"no such file: {failed_log}")
        return
    re_prefix = re.compile(r"^\d+:ASTER_[0-9.]+_")
    re_diag = re.compile(r"<F>|<EXCEPTION>|NOOK|Traceback")
    for line in open(failed_log, encoding="utf-8"):
        line = line.strip()
        if not line:
            continue
        name = re_prefix.sub("", line)
        mess = osp.join(resutest, f"{name}.mess")
        print(f"::group::code_aster testcase {name}")
        if osp.isfile(mess):
            lines = open(mess, encoding="utf-8", errors="replace").readlines()
            shown = 0
            for i, l in enumerate(lines):
                if re_diag.search(l):
                    for ctx in lines[i : i + 21]:
                        print(ctx.rstrip())
                    shown += 21
                    if shown >= 150:
                        break
            print(f"--- last lines of {name}.mess:")
            for l in lines[-40:]:
                print(l.rstrip())
        else:
            print(f"no output file for {name}")
        print("::endgroup::")


def main():
    # The build-env console is cp1252: code_aster .mess files contain box-drawing
    # characters (e.g. U+2551), which would otherwise raise UnicodeEncodeError in
    # print_failure_diagnostics() and hide every failure diagnostic.
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    aster_build_tests = os.environ.get("ASTER_BUILD_TESTS", "submit")
    if aster_build_tests == "none":
        print("ASTER_BUILD_TESTS=none, skipping code_aster testcases")
        return 0

    recipe_dir = os.environ["RECIPE_DIR"]
    src_dir = os.environ["SRC_DIR"]
    prefix = os.environ["PREFIX"]

    host_python = osp.join(prefix, "python.exe")
    if not osp.isfile(host_python):
        print(f"error: {host_python} not found")
        return 1

    known_failures = build_known_failures(recipe_dir, src_dir)
    jobs = int(os.environ.get("CPU_COUNT") or os.cpu_count() or 2)
    mem_mb = total_memory_mb()
    resutest = osp.join(src_dir, "build_testcases")

    ctest_args = [
        f"--testdir={osp.join(src_dir, 'astest')}",
        f"--resutest={resutest}",
        "--clean",
        f"--jobs={jobs}",
        f"--memory-per-slot={mem_mb // jobs}",
        "--timefactor=4.0",
        "--only-failed-results",
        f"--exclude-testlist={known_failures}",
        "-L",
        aster_build_tests,
        "-LE",
        "need_data",
    ]

    env = aster_env(prefix)

    # Rerun failed testcases twice, as done in code_aster CI.
    rc = run_ctest(host_python, ctest_args, env, prefix)
    if rc != 0:
        rc = run_ctest(host_python, ctest_args, env, prefix, rerun_failed=True)
    if rc != 0:
        rc = run_ctest(host_python, ctest_args, env, prefix, rerun_failed=True)
    if rc != 0:
        print_failure_diagnostics(resutest)
        print("code_aster testcases failed")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
