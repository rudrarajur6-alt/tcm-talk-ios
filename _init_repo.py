"""One-shot: init fresh git repo, commit, push to rudrarajur6-alt/tcm-talk-ios."""
import subprocess as sp
import os

REPO = r"C:\Users\kruth\tcm-talk-ios"
PAT = open(r"C:\Users\kruth\.git-credentials").read()
import re
PAT = re.search(r"ghp_[A-Za-z0-9]+", PAT).group(0)

def run(*args, check=True, **kw):
    r = sp.run(args, cwd=REPO, capture_output=True, text=True, **kw)
    print(">", " ".join(a if "ghp_" not in a else "***" for a in args))
    if r.stdout: print(r.stdout[-500:])
    if r.stderr: print("ERR:", r.stderr[-500:])
    if check and r.returncode != 0:
        raise SystemExit(f"command failed: {args}")
    return r

run("git", "init", "-q", "-b", "main")
run("git", "config", "user.email", "rudrarajur6@gmail.com")
run("git", "config", "user.name", "rudrarajur6-alt")
run("git", "add", "-A")
msg = """TCM Talk iOS - initial rebrand

- Set brand to TCM Talk (NCAppBranding.m, Info.plist, pbxproj)
- forceDomain=YES with domain=https://thecloudmarket.thecloud.market
- Replace AppIcon and logo imagesets (loginLogo, navigationLogo[Dark],
  app-logo-callkit, logo-action) with TCM master logo
- Add .github/workflows/build-tcm-talk-ios.yml (macos-15, Xcode 16.3,
  iOS 18.6 sim, pod install)
- Drop upstream test/lint workflows that need server setup
"""
run("git", "commit", "-q", "-m", msg)
run("git", "remote", "add", "origin",
    f"https://{PAT}@github.com/rudrarajur6-alt/tcm-talk-ios.git")
run("git", "push", "-u", "origin", "main")
print("pushed")
