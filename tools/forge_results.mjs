export function decode(result) {
 if (!result || result.isError) throw new Error('MCP tool error');
 const body = result.content?.find(x => x.type === 'text');
 if (!body) throw new Error('Missing MCP result');
 let value;
 try { value = JSON.parse(body.text); } catch { throw new Error('Malformed MCP result'); }
 if (!value || typeof value !== 'object' || value.error || value.ok === false) throw new Error('Tool operation failed');
 return value;
}
export function assertMovement(result) {
 if (decode(result).value !== true) throw new Error('Player did not move');
}
export function assertErrors(result) {
 const entries = decode(result).entries;
 if (!Array.isArray(entries) || entries.length) throw new Error('Runtime errors or missing error list');
}
