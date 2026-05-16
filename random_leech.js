/**
 * random_leech.js — Random Rate DDoW
 * ─────────────────────────────────────────────────────────────────────────────
 * ATTACK CLASSIFICATION: Random rate leech
 *
 * Implements the "random request increase" pattern from Kelly et al. (2023)
 * DoWTS — bot request rate varies randomly each window, producing
 * unpredictable invocation spikes that avoid a consistent detectable pattern.
 *
 * This tests robustness: can the detector catch an attack that produces
 * inconsistent signal rather than a sustained or escalating one?
 * Some windows will look normal, others highly anomalous.
 * Expected result: higher variance in detection metrics than the constant
 * leech — reflected in a larger SD across the 30 evaluation runs.
 *
 * ATO profile — no login, stolen session tokens simulated.
 * The randomness comes from the wide sleep range (5-120 seconds),
 * not from VU count changes. Some windows the bot fires many times,
 * others nearly silent — mimicking an unpredictable attacker.
 *
 * RUN: alongside normal_traffic.js for 24 hours
 *   Terminal 1: k6 run -e BASE_URL=$BASE_URL normal.js
 *   Terminal 2: k6 run -e BASE_URL=$BASE_URL random_leech.js
 *
 * SOURCE: Kelly, D., Glavin, F.G. & Barrett, E. (2023).
 *         DoWTS. J. Intell. Inf. Syst., 60, 325-348.
 */

import http from 'k6/http';
import { sleep, check } from 'k6';
import { Counter } from 'k6/metrics';

const checkoutCalls = new Counter('rand_checkout_calls');
const cartCalls     = new Counter('rand_cart_calls');

const BASE_URL = __ENV.BASE_URL ||
  'https://ezrgx1xle1.execute-api.eu-north-1.amazonaws.com';

// ── Load shape ────────────────────────────────────────────────────────────────
// Constant 6 VUs — randomness comes from the wide sleep range inside
// the default function, not from VU count changes.
// Inter-session sleep is randomised between 5 and 120 seconds so
// invocation counts per 5-minute window vary unpredictably.
// Some windows the bot fires many times, others nearly silent.
export const options = {
  scenarios: {
    random_leech: {
      executor: 'constant-vus',
      vus:      6,
      duration: '24h',
      tags:     { attack: 'true' },
    },
  },
  thresholds: {
    http_req_failed:   ['rate<0.05'],
    http_req_duration: ['p(95)<3000'],
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
// ATO profile — no login, stolen session tokens simulated.
// Same checkout/cart behaviour as slow leech.
// The key difference is the wide random inter-session sleep at the end,
// which produces the random rate pattern defined in DoWTS (Kelly et al., 2023).
export default function () {
  doProduct();
  jitter(0.5, 1.5);

  doCart();
  jitter(0.5, 1.0);

  doCheckout();
  jitter(1.0, 2.0);

  // 40% chance of second checkout round — same as slow leech
  if (Math.random() < 0.4) {
    doCart();
    jitter(0.3, 0.8);
    doCheckout();
  }

  // Wide random inter-session sleep — this is the source of randomness.
  // Uniformly distributed between 5 and 120 seconds so some windows
  // the bot fires many times, others almost not at all.
  randomSleep(5, 120);
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

function randomSleep(min, max) { sleep(min + Math.random() * (max - min)); }
function jitter(min, max)      { sleep(min + Math.random() * (max - min)); }
function randInt(min, max)     {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}
function pickRandom(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}