// Salesforce Canvas -> Supabase auth bridge.
// SF POSTs a signed_request here when the Canvas app loads inside Salesforce.
// We verify the HMAC signature with the Connected App consumer secret, map the
// SF user's profile/email to a dashboard role, mint a short-lived Supabase JWT
// carrying that role, and bounce to the dashboard with the token in the fragment.
//
// Required Vercel env vars:
//   SF_CONSUMER_SECRET  - Connected App consumer secret
//   SUPABASE_JWT_SECRET - Supabase project JWT secret (Settings -> API)
//   ROLE_MAP_JSON       - e.g. {"mike.perticone@bigthinkcapital.com":"exec",
//                               "00e...profileId":"exec", "*":"ops"}
const crypto = require('crypto');

module.exports = async (req, res) => {
  try {
    if (req.method !== 'POST') { res.status(405).send('POST only'); return; }
    let body = req.body;
    if (typeof body === 'string') body = Object.fromEntries(new URLSearchParams(body));
    const signed = body && body.signed_request;
    if (!signed) { res.status(400).send('missing signed_request'); return; }

    const secret = process.env.SF_CONSUMER_SECRET;
    const jwtSecret = process.env.SUPABASE_JWT_SECRET;
    if (!secret || !jwtSecret) { res.status(500).send('server not configured'); return; }

    const dot = String(signed).indexOf('.');
    if (dot < 0) { res.status(400).send('malformed signed_request'); return; }
    const sigB64 = String(signed).slice(0, dot);
    const envB64 = String(signed).slice(dot + 1);
    const expected = crypto.createHmac('sha256', secret).update(envB64).digest('base64');
    const a = Buffer.from(sigB64), b = Buffer.from(expected);
    if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) { res.status(401).send('bad signature'); return; }

    const envelope = JSON.parse(Buffer.from(envB64, 'base64').toString('utf8'));
    const user = (envelope.context && envelope.context.user) || {};
    let map = {};
    try { map = JSON.parse(process.env.ROLE_MAP_JSON || '{}'); } catch (e) { map = {}; }
    const email = String(user.email || '').toLowerCase();
    const role = map[email] || map[user.profileId] || map['*'] || 'ops';

    const now = Math.floor(Date.now() / 1000);
    const claims = {
      aud: 'authenticated', role: 'authenticated', app_role: role,
      email, sub: user.userId || 'sf-user', iss: 'sf-canvas',
      iat: now, exp: now + 8 * 60 * 60
    };
    const b64u = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
    const unsigned = b64u({ alg: 'HS256', typ: 'JWT' }) + '.' + b64u(claims);
    const jwt = unsigned + '.' + crypto.createHmac('sha256', jwtSecret).update(unsigned).digest('base64url');

    res.statusCode = 302;
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Location', '/#sbt=' + jwt);
    res.end();
  } catch (e) {
    res.status(500).send('canvas auth error');
  }
};
