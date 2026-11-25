// S2-04: recomendación de horario con y sin caché, contra el stack de Docker (backend en :3000).
// Uso, con el stack arriba: T_ASOCIADO=<token> T_SUPER=<token> node scripts/medir-cache.js
// (tokens de npm run token:dev; no se imprimen). Usa redis-cli del contenedor cootep-datos-redis-1.
const { execFileSync } = require('node:child_process');

const API = 'http://127.0.0.1:3000/api/v1';
const SIN_CACHE = 100;
const CON_CACHE = 500;

function redis(...args) {
  return execFileSync('docker', ['exec', 'cootep-datos-redis-1', 'redis-cli', ...args], { encoding: 'utf8', env: { ...process.env, MSYS_NO_PATHCONV: '1' } });
}
function borrarRecomendaciones() {
  const claves = redis('--scan', '--pattern', 'cache:recomendacion:*').split(/\r?\n/).filter(Boolean);
  if (claves.length) redis('DEL', ...claves);
  return claves.length;
}
async function pedir(ruta, token) {
  const inicio = performance.now();
  const r = await fetch(API + ruta, { headers: { Authorization: `Bearer ${token}` } });
  const cuerpo = await r.json();
  if (!r.ok) throw new Error(`${ruta} respondió ${r.status}: ${JSON.stringify(cuerpo)}`);
  return { ms: performance.now() - inicio, cuerpo };
}
const metricas = async () => (await pedir('/metricas', process.env.T_SUPER)).cuerpo.cache.recomendacion ?? { aciertos: 0, fallos: 0, errores: 0 };
const ordenar = (v) => [...v].sort((a, b) => a - b);
const percentil = (v, p) => ordenar(v)[Math.max(0, Math.ceil((p / 100) * v.length) - 1)];
const resumen = (v) => ({ n: v.length, medianaMs: +percentil(v, 50).toFixed(1), p95Ms: +percentil(v, 95).toFixed(1) });

(async () => {
  const { cuerpo: agencias } = await pedir('/agencias', process.env.T_ASOCIADO);
  const filas = agencias.filter((a) => a.activa).flatMap((a) => a.servicios.slice(0, 2).map((s) => `agenciaId=${a.id}&servicioId=${s.id}`));
  let semilla = 7;
  const azar = () => ((semilla = (semilla * 48271) % 2147483647) / 2147483647);

  // Calentamiento: conexiones abiertas y JIT, fuera de la medición.
  for (let i = 0; i < 10; i++) await pedir(`/recomendaciones?${filas[i % filas.length]}`, process.env.T_ASOCIADO);

  // Sin caché: se borra la clave antes de cada consulta, así cada una va hasta la analítica.
  const sinCache = [];
  for (let i = 0; i < SIN_CACHE; i++) {
    borrarRecomendaciones();
    sinCache.push((await pedir(`/recomendaciones?${filas[i % filas.length]}`, process.env.T_ASOCIADO)).ms);
  }

  // Con caché: 500 consultas al azar sobre las mismas filas, con la caché vacía al empezar.
  borrarRecomendaciones();
  const antes = await metricas();
  const conCache = [];
  for (let i = 0; i < CON_CACHE; i++) {
    conCache.push((await pedir(`/recomendaciones?${filas[Math.floor(azar() * filas.length)]}`, process.env.T_ASOCIADO)).ms);
  }
  const despues = await metricas();
  const aciertos = despues.aciertos - antes.aciertos;
  const fallos = despues.fallos - antes.fallos;

  console.log(JSON.stringify({
    fecha: new Date().toISOString(),
    filasDistintas: filas.length,
    sinCache: resumen(sinCache),
    conCache: { ...resumen(conCache), aciertos, fallos, errores: despues.errores - antes.errores, tasaAciertos: +(aciertos / (aciertos + fallos)).toFixed(3) },
    latenciaMediaLecturaRedisMs: despues.latenciaMediaMs,
    mejoraMediana: +(percentil(sinCache, 50) / percentil(conCache, 50)).toFixed(1),
  }, null, 2));
})().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
