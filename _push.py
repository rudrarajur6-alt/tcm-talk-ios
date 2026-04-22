"""Push latest changes."""
import subprocess as sp, re, sys

REPO = r"C:\Users\kruth\tcm-talk-ios"
PAT = re.search(r"ghp_[A-Za-z0-9]+", open(r"C:\Users\kruth\.git-credentials").read()).group(0)

def run(*a, check=True):
    r = sp.run(a, cwd=REPO, capture_output=True, text=True)
    safe = " ".join(x if "ghp_" not in x else "***" for x in a)
    print(">", safe)
    if r.stdout: print(r.stdout[-400:])
    if r.stderr: print("ERR:", r.stderr[-400:])
    if check and r.returncode != 0:
        sys.exit(r.returncode)
    return r

msg = sys.argv[1] if len(sys.argv) > 1 else "update"
run("git", "add", "-A")
run("git", "commit", "-q", "-m", msg, check=False)
run("git", "push", "origin", "main")
