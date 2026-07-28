# Mic Pause website

Marketing, privacy, and support pages for the Mic Pause App Store release.

## Before publishing

1. Set `NEXT_PUBLIC_SITE_URL` to the final HTTPS origin.
2. Run `npm test`.
3. Publish the site and use its `/privacy` and `/support` URLs in App Store
   Connect.

The public support email is `dparadis466@gmail.com`.

## Local development

Requires Node.js 22.13 or later.

```bash
npm install
npm run dev
npm test
```
