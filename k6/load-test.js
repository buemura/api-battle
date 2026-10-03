import http from 'k6/http';
import { check } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:9999';
const HEADERS = { 'Content-Type': 'application/json' };

export const options = {
  scenarios: {
    ledger: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '15s', target: 50 },
        { duration: '30s', target: 50 },
        { duration: '15s', target: 0 },
      ],
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<200'],
  },
};

const ACCOUNTS = [1000, 2000];

export default function () {
  const accountId = ACCOUNTS[Math.floor(Math.random() * ACCOUNTS.length)];
  const type = Math.random() < 0.6 ? 'credit' : 'debit';

  const created = http.post(
    `${BASE_URL}/accounts/${accountId}/transactions`,
    JSON.stringify({ type, amount: Math.ceil(Math.random() * 10000), description: 'k6' }),
    { headers: HEADERS, responseCallback: http.expectedStatuses(201, 422) },
  );
  check(created, { 'add transaction: 201 or 422': (r) => r.status === 201 || r.status === 422 });

  if (created.status === 201) {
    const tx = http.get(`${BASE_URL}/transactions/${created.json('id')}`);
    check(tx, { 'get transaction: 200': (r) => r.status === 200 });
  }

  const account = http.get(`${BASE_URL}/accounts/${accountId}`);
  check(account, {
    'get account: 200': (r) => r.status === 200,
    'balance never negative': (r) => r.json('balance') >= 0,
  });

  const history = http.get(`${BASE_URL}/accounts/${accountId}/transactions?page=1&page_size=20`);
  check(history, { 'list transactions: 200': (r) => r.status === 200 });
}
