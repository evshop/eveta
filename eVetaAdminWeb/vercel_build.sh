#!/usr/bin/env bash
set -euo pipefail

# Desde Root Directory = eVetaAdminWeb en Vercel
ADMIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$ADMIN_DIR/.." && pwd)"

cd "$REPO_ROOT"
if [[ ! -d _flutter ]]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 _flutter
fi
export PATH="$PATH:$REPO_ROOT/_flutter/bin"

cd "$ADMIN_DIR"

cat > .env <<EOF
NEXT_PUBLIC_SUPABASE_URL=${NEXT_PUBLIC_SUPABASE_URL:-}
NEXT_PUBLIC_SUPABASE_ANON_KEY=${NEXT_PUBLIC_SUPABASE_ANON_KEY:-}
NEXT_PUBLIC_CLOUDINARY_CLOUD_NAME=${NEXT_PUBLIC_CLOUDINARY_CLOUD_NAME:-}
NEXT_PUBLIC_CLOUDINARY_UPLOAD_PRESET=${NEXT_PUBLIC_CLOUDINARY_UPLOAD_PRESET:-}
EOF

flutter pub get
flutter build web --release
