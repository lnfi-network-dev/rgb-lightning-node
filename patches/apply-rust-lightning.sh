#!/bin/bash
# Apply minimal patches to rust-lightning submodule
# 1. Add is_payment_rgb_out and is_payment_rgb_in functions to rgb_utils/mod.rs
# 2. Replace is_payment_rgb with is_payment_rgb_out in outbound_payment.rs

set -e

SUBMODULE_DIR="rust-lightning/lightning/src"

# 1) Add two new functions after is_payment_rgb in mod.rs
MOD_FILE="$SUBMODULE_DIR/rgb_utils/mod.rs"
if ! grep -q 'fn is_payment_rgb_out' "$MOD_FILE"; then
  python3 -c "
import re, sys
with open('$MOD_FILE', 'r') as f:
    content = f.read()
# Find the closing brace of is_payment_rgb function and insert after it
pattern = r'(pub\(crate\) fn is_payment_rgb\(.*?\n\})'
replacement = r'''\1

/// Whether the outbound payment is colored
pub(crate) fn is_payment_rgb_out(ldk_data_dir: &Path, payment_hash: &PaymentHash) -> bool {
\tget_rgb_payment_info_path(payment_hash, ldk_data_dir, false).exists()
}

/// Whether the inbound payment is colored
pub(crate) fn is_payment_rgb_in(ldk_data_dir: &Path, payment_hash: &PaymentHash) -> bool {
\tget_rgb_payment_info_path(payment_hash, ldk_data_dir, true).exists()
}'''
result = re.sub(pattern, replacement, content, count=1, flags=re.DOTALL)
with open('$MOD_FILE', 'w') as f:
    f.write(result)
"
  echo "Patched: $MOD_FILE (added is_payment_rgb_out, is_payment_rgb_in)"
fi

# 2) Replace is_payment_rgb with is_payment_rgb_out in outbound_payment.rs
OUTBOUND_FILE="$SUBMODULE_DIR/ln/outbound_payment.rs"
if grep -q 'is_payment_rgb,' "$OUTBOUND_FILE"; then
  python3 -c "
with open('$OUTBOUND_FILE', 'r') as f:
    content = f.read()
content = content.replace('is_payment_rgb,', 'is_payment_rgb_out,')
content = content.replace('is_payment_rgb(&', 'is_payment_rgb_out(&')
with open('$OUTBOUND_FILE', 'w') as f:
    f.write(content)
"
  echo "Patched: $OUTBOUND_FILE (is_payment_rgb -> is_payment_rgb_out)"
fi

echo "All patches applied."
