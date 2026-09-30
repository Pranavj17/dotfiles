#!/usr/bin/env python3
"""Turn a nix-darwin switch log into a short transcript.

Errors, warnings, and build lines pass through. Repetitive
"Using <cask>" and "setting up …" lines are labeled instead of dumped raw.
"""
import sys

phase = None
brew = []

SYSTEM_PREFIXES = (
    "setting up ",
    "applying patches",
    "user defaults",
    "restarting ",
    "configuring ",
    "setting nvram",
)


def header(name):
    global phase
    if phase != name:
        phase = name
        print(f"\n{name}", flush=True)


def emit(text):
    print(f"  {text}", flush=True)


def flush_brew(ok=True):
    global brew
    if not brew:
        return
    label = "ok" if ok else "tried"
    emit(f"homebrew  {len(brew)} {label}: {', '.join(brew)}")
    brew = []


def system_line(line):
    if line.endswith("..."):
        line = line[:-3]
    return line


for raw in sys.stdin:
    line = raw.rstrip("\n")
    if not line.strip():
        continue
    low = line.lower()

    if "is not owned by you" in line and "$HOME" in line:
        header("build")
        emit("note      sudo is root, so Nix uses /var/root as HOME. Not a failure.")
        continue

    if "Git tree" in line and "uncommitted changes" in line:
        header("build")
        emit("note      uncommitted changes in this repo are included.")
        continue

    if line.startswith("Using "):
        brew.append(line.split(None, 1)[1])
        continue

    if "brew bundle" in line and "complete" in line:
        header("activate")
        flush_brew()
        continue

    if "brew bundle" in line and "failed" in low:
        header("activate")
        flush_brew(ok=False)
        emit(line)
        continue

    if "error:" in low or "failed" in low or "FAIL" in line:
        header(phase or "build")
        flush_brew(ok=False)
        emit(line)
        continue

    if line.startswith("building the system configuration"):
        header("build")
        emit("nix-darwin configuration")
        continue

    if line.startswith("Homebrew bundle"):
        header("activate")
        emit("homebrew  bundle")
        continue

    if line.startswith(SYSTEM_PREFIXES):
        header("activate")
        flush_brew()
        emit("system    " + system_line(line))
        continue

    if line.startswith("Activating home-manager configuration"):
        header("activate")
        flush_brew()
        emit("home      " + line.rsplit(None, 1)[-1])
        continue

    if line.startswith("Starting Home Manager"):
        continue

    if line.startswith("Activating "):
        header("activate")
        emit("home      " + line[len("Activating ") :])
        continue

    if line.startswith("warning:") or line.startswith("trace: warning:"):
        header(phase or "build")
        emit(line)
        continue

    header(phase or "build")
    flush_brew()
    emit(line)

flush_brew()
