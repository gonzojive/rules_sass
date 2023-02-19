"""Mirror of release info

TODO: generate this file from GitHub API"""

# The sass version numbers are taken from
# https://github.com/sass/dart-sass/releases

# The integrity hashes can be computed with
# shasum -b -a 384 [downloaded file] | awk '{ print $1 }' | xxd -r -p | base64
TOOL_VERSIONS = {
    "1.58.8": {
        #"x86_64-apple-darwin": "...",
        #"aarch64-apple-darwin": "...",
        #"x86_64-pc-windows-msvc": "...",
        "x86_64-unknown-linux-gnu": {
            "integrity": "sha256-qKLpxtQiHe+j0LkrWEx+Kjmg9iSW5aC7UzhSWcEbXrY=",
            "urls": [
                "https://github.com/sass/dart-sass/releases/download/1.58.3/dart-sass-1.58.3-linux-x64.tar.gz",
            ],
        },
    },
}
