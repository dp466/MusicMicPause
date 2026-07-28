import assert from "node:assert/strict";
import test from "node:test";

async function render(pathname) {
  const workerUrl = new URL("../dist/server/index.js", import.meta.url);
  workerUrl.searchParams.set("test", `${process.pid}-${Date.now()}-${pathname}`);
  const { default: worker } = await import(workerUrl.href);

  return worker.fetch(
    new Request(`http://localhost${pathname}`, {
      headers: { accept: "text/html" },
    }),
    {
      ASSETS: {
        fetch: async () => new Response("Not found", { status: 404 }),
      },
    },
    {
      waitUntil() {},
      passThroughOnException() {},
    },
  );
}

test("renders the Mic Pause marketing page", async () => {
  const response = await render("/");
  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type") ?? "", /^text\/html\b/i);

  const html = await response.text();
  assert.match(html, /Your music knows when to pause/);
  assert.match(html, /No recording/);
  assert.match(html, /Coming soon to the Mac App Store/);
  assert.doesNotMatch(html, /codex-preview|Your site is taking shape/i);
});

test("renders the privacy policy", async () => {
  const response = await render("/privacy");
  assert.equal(response.status, 200);
  const html = await response.text();
  assert.match(html, /Nothing to collect/);
  assert.match(html, /does not collect, store, sell, or transmit personal data/);
});

test("renders support guidance", async () => {
  const response = await render("/support");
  assert.equal(response.status, 200);
  const html = await response.text();
  assert.match(html, /Apple Music is not pausing/);
  assert.match(html, /dparadis466@gmail\.com/);
});
