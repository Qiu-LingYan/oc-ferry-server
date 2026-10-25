const key = process.env.OCF_KEY;
const base = 'http://127.0.0.1:41980';
const post = (body) => fetch(base + '/v1/chat/completions', {
  method: 'POST',
  headers: { Authorization: 'Bearer ' + key, 'Content-Type': 'application/json' },
  body: JSON.stringify(body),
});

const t0 = Date.now();
const r = await post({ model: 'glm-5.3-flash-free', messages: [{ role: 'user', content: '用一句话说明你在干什么' }], stream: false });
const j = await r.json();
console.log('非流式 HTTP', r.status, '| 耗时', Date.now() - t0, 'ms');
console.log('回复:', JSON.stringify(j.choices?.[0]?.message?.content ?? j.error));

const s = await post({ model: 'glm-5.3-flash-free', messages: [{ role: 'user', content: '数到五，只输出数字' }], stream: true });
let buf = '', chunks = 0;
const reader = s.body.getReader();
const dec = new TextDecoder();
while (true) { const { done, value } = await reader.read(); if (done) break; chunks++; buf += dec.decode(value, { stream: true }); }
console.log('流式 HTTP', s.status, '| 分片', chunks, '| 字节', buf.length);
console.log('流式结尾:', JSON.stringify(buf.slice(-200)));

// 带工具调用的请求（NewAPI 客户端常见）
const tools = [{ type: 'function', function: { name: 'get_weather', description: 'Get weather', parameters: { type: 'object', properties: { city: { type: 'string' } }, required: ['city'] } } }];
const t1 = await post({ model: 'glm-5.3-flash-free', messages: [{ role: 'user', content: '北京天气怎么样？用工具查。' }], tools, stream: false });
const tj = await t1.json();
console.log('工具调用 HTTP', t1.status, '| tool_calls:', JSON.stringify(tj.choices?.[0]?.message?.tool_calls ?? tj.choices?.[0]?.message?.content ?? tj.error).slice(0, 300));
