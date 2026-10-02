import {test} from 'node:test';
import assert from 'node:assert/strict';
import {decode,assertMovement,assertErrors} from '../tools/forge_results.mjs';
const result = value => ({content:[{type:'text',text:JSON.stringify(value)}]});
test('valid move and errors',()=>{assertMovement(result({value:true}));assertErrors(result({entries:[]}));});
test('MCP isError fails',()=>assert.throws(()=>decode({isError:true})));
test('false or missing assertion fails',()=>{assert.throws(()=>assertMovement(result({value:false})));assert.throws(()=>assertMovement(result({})));});
test('runtime errors fail',()=>assert.throws(()=>assertErrors(result({entries:[{message:'script failed'}]}))));
test('malformed response fails',()=>assert.throws(()=>decode({content:[{type:'text',text:'not json'}]})));
