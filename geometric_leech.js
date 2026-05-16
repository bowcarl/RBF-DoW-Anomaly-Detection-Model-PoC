import http from 'k6/http';
import { sleep, check } from 'k6';
import { Counter } from 'k6/metrics';

const checkoutCalls = new Counter('geo_checkout_calls');
const cartCalls     = new Counter('geo_cart_calls');

const BASE_URL = __ENV.BASE_URL ||
  'https://ezrgx1xle1.execute-api.eu-north-1.amazonaws.com';

export const options = {
  stages: [
    { duration: '4h', target: 1  },
    { duration: '4h', target: 2  },
    { duration: '4h', target: 4  },
    { duration: '4h', target: 8  },
    { duration: '4h', target: 16 },
    { duration: '4h', target: 32 },
  ],
  thresholds: {
    http_req_failed:   ['rate<0.05'],
    http_req_duration: ['p(95)<3000'],
  },
};

const HEADERS = {
  'Content-Type': 'application/json',
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
};

export default function () {
  http.get(`${BASE_URL}/product?id=${randInt(1, 200)}`,
    { headers: HEADERS, tags: { endpoint: 'product' } });
  jitter(0.5, 1.5);

  http.post(`${BASE_URL}/cart`,
    JSON.stringify({ productId: randInt(1, 200), quantity: randInt(1, 3), action: 'add' }),
    { headers: HEADERS, tags: { endpoint: 'cart' } });
  cartCalls.add(1);
  jitter(0.5, 1.0);

  http.post(`${BASE_URL}/checkout`,
    JSON.stringify({
      cartId:       `cart_${randInt(1000, 9999)}`,
      paymentToken: `tok_${Math.random().toString(36).substr(2, 16)}`,
      address:      '123 Bot Street, Nowhere, 00000',
    }),
    { headers: HEADERS, tags: { endpoint: 'checkout' } });
  checkoutCalls.add(1);
  jitter(1.0, 2.0);

  if (Math.random() < 0.4) {
    http.post(`${BASE_URL}/cart`,
      JSON.stringify({ productId: randInt(1, 200), quantity: randInt(1, 3), action: 'add' }),
      { headers: HEADERS, tags: { endpoint: 'cart' } });
    cartCalls.add(1);
    jitter(0.3, 0.8);

    http.post(`${BASE_URL}/checkout`,
      JSON.stringify({
        cartId:       `cart_${randInt(1000, 9999)}`,
        paymentToken: `tok_${Math.random().toString(36).substr(2, 16)}`,
        address:      '123 Bot Street, Nowhere, 00000',
      }),
      { headers: HEADERS, tags: { endpoint: 'checkout' } });
    checkoutCalls.add(1);
  }

  jitter(15, 30);
}

function jitter(min, max) { sleep(min + Math.random() * (max - min)); }
function randInt(min, max) {
  return Math.floor(Math.random() * (max - min + 1)) + min;
}