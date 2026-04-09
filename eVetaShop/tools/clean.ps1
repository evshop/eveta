$ErrorActionPreference = "Stop"

$paths = @(
  ".dart_tool",
  "build",
  "android\\.gradle",
  "android\\app\\build",
  "ios\\Pods",
  "ios\\.symlinks",
  "ios\\Flutter\\Flutter.framework",
  "ios\\Flutter\\Flutter.podspec"
)

foreach ($p in $paths) {
  if (Test-Path $p) {
    Remove-Item -Force -Recurse $p
  }
}

