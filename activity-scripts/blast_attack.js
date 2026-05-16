/**
 * blast_attack.js — Blast DDoW
 * ─────────────────────────────────────────────────────────────────────────────
 * ATTACK CLASSIFICATION: Blast Denial-of-Wallet (Kelly et al., 2021)
 *
 * A sudden high-volume spike across all functions simultaneously.
 * This is the attack pattern Gringotts was explicitly designed to detect
 * (Shen et al., 2022). Including this scenario provides a fair evaluation:
 * it demonstrates Gringotts performing well on its intended use case while
 * allowing comparison of both detectors across attack archetypes.
 *
 * Unlike the slow leech, this attack hits ALL functions including login —
 * so the checkout-to-login ratio stays near-normal. Gringotts detects it
 * through absolute volume spikes on individual functions. The IF detects it
 * through elevated totalInvocations, entropy shift, and cost signal.
 *
 * RUN: alongside normal_traffic.js for 4 hours
 *   Terminal 1: k6 run -e BASE_URL=$BASE_URL normal.js
 *   Terminal 2: k6 run -e BASE_URL=$BASE_URL blast_attack.js
 *
 * SOURCE: Kelly, D., Glavin, F.G. & Barrett, E. (2021).
 *         Denial of Wallet. JISA, 60.
 *         Shen, J. et al. (2022). Gringotts. ACM CCS 2022.
 */

import http from 'k6/http';
import { sleep, check } from 'k6';
import { Counter } from 'k6/metrics';

const checkoutCalls = new Counter('blast_checkout_calls');
const cartCalls     = new Counter('blast_cart_calls');

const BASE_URL = __ENV.BASE_URL ||
  'https://ezrgx1xle1.execute-api.eu-north-1.amazonaws.com';

// ── Load shape ────────────────────────────────────────────────────────────────
// Ramp up to 150 VUs against your 50 legitimate VUs = 3:1 bot ratio at peak.
// Total duration 4 hours — enough for 48 fingerprint windows.
// This produces the "sudden violent influx" Kelly et al. define as Blast DoW.
export const options = {
  stages: [
    { duration: '30m', target: 50  },   // ramp up
    { duration: '30m', target: 150 },   // escalate to peak
    { duration: '2h',  target: 150 },   // sustained blast
    { duration: '30m', target: 50  },   // ramp down
    { duration: '30m', target: 0   },   // wind down
  ],
  thresholds: {
    http_req_failed:   ['rate<0.10'],
    http_req_duration: ['p(95)<5000'],
  },
};

const HEADERS = {
  'Content-Type': 'application/json',
  'User-Agent': pickRandom([
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/605.1.15',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15',
  ]),
};

// ── Bot profile ───────────────────────────────────────────────────────────────
// Hits ALL functions including login — this keeps the checkout-to-login ratio
// near-normal, which means the IF relational features are less activated.
// Detection comes from absolute volume spike and cost signal instead.
// This is a fair test: if Gringotts catches it and IF also catches it,
// that demonstrates both detectors work on their respective strengths.
export default function () {
  doLogin();
  jitter(0.1, 0.3);

  doSearch();
  jitter(0.1, 0.2);

  doProduct();
  jitter(0.1, 0.2);

  doCart();
  jitter(0.1, 0.2);

  doCheckout();
  jitter(0.2, 0.5);
}

function doLogin() {
  const r = http.post(`${BASE_URL}/login`,
    JSON.stringify({ username: `user_${randInt(1, 9999)}`,
                     password: 'password123' }),
    { headers: HEADERS, tags: { endpoint: 'login' } });
  check(r, { 'login ok': (r) => r.status < 500 });
}
function doSearch() {
  const r = http.get(`${BASE_URL}/search?q=product${randInt(1, 100)}`,
    { headers: HEADERS, tags: { endpoint: 'search' } });
  check(r, { 'search ok': (r) => r.status < 500 });
}
function doProduct() {
  const r = http.get(`${BASE_URL}/product?id=${randInt(1, 200)}`,
    { headers: HEADERS, tags: { endpoint: 'product' } });
  check(r, { 'product ok': (r) => r.status < 500 });
}
function doCart() {
  const r = http.post(`${BASE_URL}/cart`,
    JSON.stringify({ productId: randInt(1, 200),
                     quantity:  randInt(1, 3), action: 'add' }),
    { headers: HEADERS, tags: { endpoint: 'cart' } });
  check(r, { 'cart ok': (r) => r.status < 500 });
  cartCalls.add(1);
}
function doCheckout() {
  const r = http.post(`${BASE_URL}/checkout`,
    JSON.stringify({
      cartId:       `cart_${randInt(1000, 9999)}`,
      paymentToken: `tok_${Math.random().toString(36).substr(2, 16)}`,
      address:      '123 Bot Street, Nowhere, 00000',
    }),
    { headers: HEADERS, tags: { endpoint: 'checkout' } });
  check(r, { 'checkout ok': (r) => r.status < 500 });
  checkoutCalls.add(1);
}

function jitter(min, max) { sleep(min + Math.random() * (max - min)); }
function randInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}
function pickRandom(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}
