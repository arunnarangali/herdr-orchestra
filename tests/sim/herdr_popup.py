#!/usr/bin/env python3
"""herdr_popup.py <plugin_root> <entrypoint> <cwd> <keys> <after_s> <wait_s>: open a plugin popup the way herdr 0.9.5
does (src/app/api/plugins/mod.rs + panes.rs + plugin_command.rs): the manifest's command, its first word resolved against
the plugin folder only when it has a "/", the other words unchanged, started in <cwd> (the --cwd folder) in a terminal,
with HERDR_PLUGIN_ROOT and friends set. Prints what it drew plus RUNNING (still open after wait_s) or EXIT <code>."""
import os, pty, select, sys, time, tomllib
root, entry, cwd = os.path.realpath(sys.argv[1]), sys.argv[2], sys.argv[3]
keys, after, wait = sys.argv[4].encode().decode("unicode_escape").encode(), float(sys.argv[5]), float(sys.argv[6])
pane = next(p for p in tomllib.load(open(os.path.join(root, "herdr-plugin.toml"), "rb"))["panes"] if p["id"] == entry)
argv = list(pane["command"])
if not os.path.isabs(argv[0]) and "/" in argv[0]:   # program_for_cwd: only a path with a separator is the plugin's
    argv[0] = os.path.join(root, argv[0].removeprefix("./"))
env = dict(os.environ, HERDR_ENV="1", HERDR_PLUGIN_ROOT=root, HERDR_PLUGIN_ENTRYPOINT_ID=entry,
           HERDR_PLUGIN_ID="herdr-orchestra.board", PWD=cwd)
env.pop("HERDR_PANE_ID", None)                       # a popup gets no pane id
pid, fd = pty.fork()
if pid == 0:
    os.chdir(cwd)
    os.execvpe(argv[0], argv, env)
out, t0, sent, res = b"", time.time(), not keys, None
while time.time() - t0 < wait:
    if not sent and time.time() - t0 >= after:
        os.write(fd, keys); sent = True
    if select.select([fd], [], [], 0.1)[0]:
        try:
            out += os.read(fd, 65536)
        except OSError:
            pass
    p, st = os.waitpid(pid, os.WNOHANG)
    if p:
        res = f"EXIT {os.waitstatus_to_exitcode(st)}"; break
if res is None:
    os.kill(pid, 9); os.waitpid(pid, 0); res = "RUNNING"
sys.stdout.write(out.decode(errors="replace") + "\n" + res + "\n")
