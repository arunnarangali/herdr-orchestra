#!/usr/bin/env python3
"""inpty.py <keys> <after_s> <wait_s> cmd... : run cmd in a terminal (pty) like a herdr popup, type <keys> after
<after_s> seconds, and print what it drew plus RUNNING (still open after wait_s, then killed) or EXIT <code>.
Keys split by | are typed one after another, 0.6s apart (f|\r|q: f, then Enter, then q)."""
import os, pty, select, sys, time
keys, after, wait, cmd = sys.argv[1], float(sys.argv[2]), float(sys.argv[3]), sys.argv[4:]
keys = [k.encode().decode("unicode_escape").encode() for k in keys.split("|")] if keys else []
pid, fd = pty.fork()
if pid == 0:
    os.execvp(cmd[0], cmd)
out, t0, res = b"", time.time(), None
while time.time() - t0 < wait:
    if keys and time.time() - t0 >= after:
        os.write(fd, keys.pop(0)); after += 0.6
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
