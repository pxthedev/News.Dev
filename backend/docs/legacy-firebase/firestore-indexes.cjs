const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

// Aplica somente índices compostos ausentes. Não remove índices, dados ou regras.
async function main() {
  const root = path.resolve(__dirname, '../..');
  const envFile = fs.readFileSync(path.join(root, 'backend/.env'), 'utf8');
  const config = Object.fromEntries(envFile.split(/\r?\n/).filter(l => /^[A-Z][A-Z0-9_]*=/.test(l.trim())).map(l => {
    const pos = l.indexOf('=');
    return [l.slice(0, pos).trim(), l.slice(pos + 1).trim().replace(/^(['"])(.*)\1$/, '$2')];
  }));
  const keyPath = config.GOOGLE_APPLICATION_CREDENTIALS || process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!keyPath) throw new Error('Configure GOOGLE_APPLICATION_CREDENTIALS no backend/.env.');
  const key = JSON.parse(fs.readFileSync(path.resolve(root, 'backend', keyPath), 'utf8'));
  const project = config.FIREBASE_PROJECT_ID;
  if (!project || project !== key.project_id) throw new Error('O projeto da conta de serviço deve corresponder ao FIREBASE_PROJECT_ID.');
  const b64 = x => Buffer.from(typeof x === 'string' ? x : JSON.stringify(x)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  const unsigned = `${b64({alg: 'RS256', typ: 'JWT'})}.${b64({iss: key.client_email, scope: 'https://www.googleapis.com/auth/cloud-platform', aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600})}`;
  const assertion = `${unsigned}.${crypto.sign('RSA-SHA256', Buffer.from(unsigned), key.private_key).toString('base64url')}`;
  const authResponse = await fetch('https://oauth2.googleapis.com/token', {method: 'POST', body: new URLSearchParams({grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion}), signal: AbortSignal.timeout(30000)});
  const auth = await authResponse.json();
  if (!authResponse.ok) throw new Error(`OAuth falhou: ${authResponse.status} ${auth.error || ''}`);
  async function request(url, body) {
    const response = await fetch(url, {method: body ? 'POST' : 'GET', headers: {Authorization: `Bearer ${auth.access_token}`, 'Content-Type': 'application/json'}, ...(body ? {body: JSON.stringify(body)} : {}), signal: AbortSignal.timeout(30000)});
    const data = await response.json();
    if (!response.ok) throw new Error(`Firestore ${response.status}: ${data.error?.message || 'Falha na API'}`);
    return data;
  }
  const definitions = JSON.parse(fs.readFileSync(path.join(root, 'firestore.indexes.json'), 'utf8')).indexes;
  const signature = i => JSON.stringify([i.queryScope, i.fields.filter(f => f.fieldPath !== '__name__')]);
  let ready = 0, building = 0, missing = 0, created = 0;
  for (const group of new Set(definitions.map(i => i.collectionGroup))) {
    const endpoint = `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(project)}/databases/(default)/collectionGroups/${encodeURIComponent(group)}/indexes`;
    const existing = [];
    let pageToken;
    do {
      const page = await request(`${endpoint}${pageToken ? `?pageToken=${encodeURIComponent(pageToken)}` : ''}`);
      existing.push(...(page.indexes || []));
      pageToken = page.nextPageToken;
    } while (pageToken);
    for (const definition of definitions.filter(i => i.collectionGroup === group)) {
      const found = existing.find(i => signature(i) === signature(definition));
      const label = `${group}: ${definition.fields.map(f => `${f.fieldPath}/${f.order || f.arrayConfig}`).join(', ')}`;
      if (found) {
        if (found.state === 'READY') ready++; else building++;
        console.log(`${found.state} ${label}`);
      } else {
        missing++;
        if (process.argv.includes('--apply')) {
          await request(endpoint, {queryScope: definition.queryScope, fields: definition.fields});
          created++;
          console.log(`CREATING ${label}`);
        } else console.log(`MISSING ${label}`);
      }
    }
  }
  console.log(JSON.stringify({project, defined: definitions.length, ready, building, missing, created}));
}
main().catch(error => { console.error(error.message); process.exitCode = 1; });
