// 并发排队逻辑的最小验证：不碰上游，只用假后端。
process.env.FERRY_MAX_CONCURRENCY = '2';
process.env.FERRY_QUEUE_WAIT_MS = '5000';
process.env.FERRY_MODEL_ID = 'slug';
const { createServer } = await import('./src/server.js');
const models = [{ id: 'opencode/x-free', name: 'X Free', toolcall: true }];
let inflight = 0, peak = 0;
const backend = { complete: async () => { inflight++; peak = Math.max(peak, inflight); await new Promise(r => setTimeout(r, 300)); inflight--; return { choices: [{ index: 0, message: { role: 'assistant', content: 'ok' } }] }; } };
const server = createServer({ key: 'k', selectModel: () => {}, backend, getModels: () => models, refresh: () => {}, importModels: () => {}, findConfig: () => {}, setSystemProxy: () => {}, probe: () => {}, status: () => ({ phase: 'ready', availableModels: ['x'] }) });
await new Promise(r => server.listen(41999, '127.0.0.1', r));
const one = i => fetch('http://127.0.0.1:41999/v1/chat/completions', { method: 'POST', headers: { Authorization: 'Bearer k', 'Content-Type': 'application/json' }, signal: AbortSignal.timeout(15000), body: JSON.stringify({ model: 'x-free', messages: [{ role: 'user', content: 'hi' + i }] }) }).then(async r => ({ i, s: r.status, body: (await r.text()).slice(0, 60) }));
const t = Date.now();
const rs = await Promise.all([1, 2, 3, 4, 5].map(one));
rs.forEach(r => console.log('req' + r.i, r.s, r.s === 200 ? 'ok' : r.body));
console.log('峰值并发:', peak, '| 总耗时', Date.now() - t, 'ms（5 个请求 / 上限 2 → 应约 900ms）');
server.close();
process.exit(0);
