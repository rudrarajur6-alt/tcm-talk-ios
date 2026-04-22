import urllib.request, zipfile, io, sys, re

PAT = re.search(r"ghp_[A-Za-z0-9]+", open(r"C:\Users\kruth\.git-credentials").read()).group(0)
job_id = sys.argv[1] if len(sys.argv) > 1 else "72530749434"
mode = sys.argv[2] if len(sys.argv) > 2 else "tail"
url = f"https://api.github.com/repos/rudrarajur6-alt/tcm-talk-ios/actions/jobs/{job_id}/logs"

class NoAuthRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        nr = super().redirect_request(req, fp, code, msg, headers, newurl)
        if nr is not None:
            nr.headers.pop("Authorization", None)
        return nr

opener = urllib.request.build_opener(NoAuthRedirect())
req = urllib.request.Request(url, headers={"Authorization": f"token {PAT}"})
data = opener.open(req).read()

text = data.decode("utf-8", errors="replace")
if mode == "tail":
    print(text[-20000:])
elif mode == "full":
    print(text)
elif mode == "error":
    # find lines with error
    for i, line in enumerate(text.splitlines()):
        if "error" in line.lower() or "fail" in line.lower() or "##[error]" in line:
            print(line)
else:
    # grep mode
    for line in text.splitlines():
        if mode in line:
            print(line)
