import { mkdir, writeFile } from 'node:fs/promises';

const raw = process.env.API_BASE_URL;
if (!raw) throw new Error('Configura API_BASE_URL en frontend/.env o en el entorno de despliegue.');
const url = new URL(raw);
if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password || url.search || url.hash) {
  throw new Error('API_BASE_URL debe ser una URL HTTP(S) sin credenciales, query ni fragmento.');
}
if (url.protocol === 'http:' && !['localhost', '127.0.0.1', '[::1]'].includes(url.hostname)) {
  throw new Error('Usa HTTPS fuera del desarrollo local.');
}
const demo = process.env.DEMO_ENABLED ?? 'false';
if (!['true', 'false'].includes(demo)) throw new Error('DEMO_ENABLED debe ser true o false.');
await mkdir('public', { recursive: true });
await writeFile('public/config.json', JSON.stringify({ apiBaseUrl: raw.replace(/\/+$/, ''), demoEnabled: demo === 'true' }, null, 2));
console.log('Configuración pública generada.');
