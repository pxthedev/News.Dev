const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');

// One-way, read-only Firestore export into a private SQL file; no cloud writes.
async function main() {
  const root = path.resolve(__dirname, '../..');
  const envPath = process.env.FIREBASE_EXPORT_ENV || path.join(root, 'backend/.env.firebase.backup');
  const config = Object.fromEntries(fs.readFileSync(envPath, 'utf8').split(/\r?\n/).filter(l => /^[A-Z][A-Z0-9_]*=/.test(l.trim())).map(l => {
    const pos=l.indexOf('=');return [l.slice(0,pos).trim(),l.slice(pos+1).trim().replace(/^(['"])(.*)\1$/, '$2')];
  }));
  const key = JSON.parse(fs.readFileSync(path.resolve(path.dirname(envPath), config.GOOGLE_APPLICATION_CREDENTIALS), 'utf8'));
  const project = config.FIREBASE_PROJECT_ID;
  if (!project || key.project_id !== project) throw new Error('Projeto e credenciais do backup não correspondem.');
  const b64 = obj => Buffer.from(JSON.stringify(obj)).toString('base64url');
  const now=Math.floor(Date.now()/1000);
  const head=`${b64({alg:'RS256',typ:'JWT'})}.${b64({iss:key.client_email,scope:'https://www.googleapis.com/auth/datastore',aud:'https://oauth2.googleapis.com/token',iat:now,exp:now+3600})}`;
  const assertion=`${head}.${crypto.sign('RSA-SHA256', Buffer.from(head), key.private_key).toString('base64url')}`;
  const response=await fetch('https://oauth2.googleapis.com/token',{method:'POST',body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion}),signal:AbortSignal.timeout(30000)});
  const auth=await response.json();if(!response.ok)throw new Error(`OAuth ${response.status}`);
  const base=`https://firestore.googleapis.com/v1/projects/${encodeURIComponent(project)}/databases/(default)/documents`;
  async function list(collection) {
    const rows=[];let page;
    do {
      const res=await fetch(`${base}/${collection}?pageSize=300${page?'&pageToken='+encodeURIComponent(page):''}`,{headers:{Authorization:`Bearer ${auth.access_token}`},signal:AbortSignal.timeout(30000)});
      const result=await res.json();if(!res.ok)throw new Error(`Firestore ${res.status}: ${result.error?.message||'erro'}`);
      rows.push(...(result.documents||[]));page=result.nextPageToken;
    }while(page);
    return rows;
  }
  function value(v){
    if('nullValue' in v)return null;
    if('stringValue' in v)return v.stringValue;
    if('booleanValue' in v)return v.booleanValue;
    if('integerValue' in v){const n=Number(v.integerValue);if(!Number.isSafeInteger(n))throw new Error('Inteiro excede precisão segura. Use um exportador com BigInt.');return n;}
    if('doubleValue' in v)return v.doubleValue;
    if('timestampValue' in v){
      const t=v.timestampValue;const m=t.match(/^(.*?)(?:\.(\d+))?Z$/);
      if(!m)throw new Error('Timestamp inesperado.');
      return `${m[1]}.${(m[2]||'').padEnd(9,'0')}Z`;
    }
    if('arrayValue' in v)return (v.arrayValue.values||[]).map(value);
    if('mapValue' in v)return fields(v.mapValue.fields||{});
    throw new Error('Tipo Firestore não suportado; exportação interrompida sem importar dados.');
  }
  function fields(map){return Object.fromEntries(Object.entries(map).map(([k,v])=>[k,value(v)]));}
  const quote=s=>"'"+s.replace(/'/g,"''")+"'";
  const inserts=[];const counts={};
  function append(table,owner,doc){
    const id=doc.name.split('/').at(-1);const data=fields(doc.fields||{});
    inserts.push(`insert into fionova.${table}(owner_id,id,data) values (${quote(owner)},${quote(id)},${quote(JSON.stringify(data))}::jsonb);`);
    counts[table]=(counts[table]||0)+1;return id;
  }
  const collections={users:'users',emails:'emails',articles:'articles',liveEvents:'live_events',readerEvents:'reader_events',sources:'sources',imports:'imports'};
  for(const [collection,table] of Object.entries(collections)){
    const docs=await list(collection);
    for(const doc of docs){
      const id=append(table,'',doc);
      if(collection==='users'){
        for(const [sub,target] of Object.entries({saved:'user_saved',reads:'user_reads',readingDays:'user_reading_days',alerts:'user_alerts'})){
          for(const child of await list(`users/${encodeURIComponent(id)}/${sub}`))append(target,id,child);
        }
      }
    }
  }
  // Atomic import, intentionally without ON CONFLICT: existing IDs must be reviewed.
  const sql='-- PRIVATE: account data/password hashes. Never commit or publish.\n-- Apply only AFTER the schema migration, to an empty destination.\n\\set ON_ERROR_STOP on\nset standard_conforming_strings=on;\nbegin;\n'+inserts.join('\n')+'\ncommit;\n';
  const output=path.join(root,'artifacts/migration');fs.mkdirSync(output,{recursive:true});
  const destination=path.join(output,'firestore-to-supabase.sql');
  fs.writeFileSync(destination,sql,{flag:'wx'});
  fs.writeFileSync(path.join(output,'summary.json'),JSON.stringify({project,exportedAt:new Date().toISOString(),counts,excluded:['sessions','refreshTokens','passwordResets','outbox','pushTokens','socialIdentities'],sourceModified:false},null,2));
  console.log(JSON.stringify({file:destination,counts,sourceModified:false}));
}
main().catch(error=>{console.error(error.message);process.exitCode=1;});
