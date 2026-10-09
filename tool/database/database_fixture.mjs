import {PGlite} from '@electric-sql/pglite';
import {pgcrypto} from '@electric-sql/pglite/contrib/pgcrypto';
export async function database(){
 if(!process.env.DATABASE_URL)return new PGlite({extensions:{pgcrypto}});
 const {Client}=await import('pg');
 const admin=new Client({connectionString:process.env.DATABASE_URL});await admin.connect();
 const name='dinnermap_test_'+crypto.randomUUID().replaceAll('-','');await admin.query(`create database ${name}`);
 const url=new URL(process.env.DATABASE_URL);url.pathname='/'+name;
 const client=new Client({connectionString:url.toString()});await client.connect();
 return {exec:s=>client.query(s),query:(s,p)=>client.query(s,p?.map(v=>v!==null&&typeof v==='object'?JSON.stringify(v):v)),connect:async()=>{const c=new Client({connectionString:url.toString()});await c.connect();return c;},close:async()=>{await client.end();await admin.query(`drop database ${name}`);await admin.end();}};
}
