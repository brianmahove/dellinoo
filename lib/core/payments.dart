/// Public HTTPS URL of the `payments/` Cloudflare Worker (not secret — it
/// only proxies to Paynow using its own server-side Integration Key, which
/// never reaches this app). See payments/README.md.
const kPaymentsWorkerUrl = 'https://dellinoo-payments.dellinoo.workers.dev';
