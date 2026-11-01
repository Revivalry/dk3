// SPDX-License-Identifier: GPL-2.0-or-later
// Shared mechanism: exact bounded particle-index division with draw-wide reciprocals.
// n < 262144, 1 <= divisor <= 65536; magic = ceil(2^32 / divisor), except d=1.
// The high product is the true quotient or one too large. Its product with d
// remains below 2^19 in this domain, so the correction cannot overflow.
uint weatherQuotient(uint n, uint divisor, uint magic) {
    if (divisor == 1u) return n;
    uint quotient, low;
    umulExtended(n, magic, quotient, low);
    return quotient - uint(quotient * divisor > n);
}
