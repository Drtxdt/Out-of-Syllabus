import {Client} from './godot-forge/node_modules/@modelcontextprotocol/sdk/dist/esm/client/index.js';
import {StdioClientTransport} from './godot-forge/node_modules/@modelcontextprotocol/sdk/dist/esm/client/stdio.js';
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import {decode,assertMovement,assertErrors} from './forge_results.mjs';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const runId=process.env.OOS_QA_PROFILE || 'forge-'+Date.now();
const reportsDir=path.join(root,'reports/v0.2',runId);fs.mkdirSync(reportsDir,{recursive:true});
if(!process.env.GODOT_PATH) throw Error('Set GODOT_PATH. Start a QA editor explicitly; this script never restarts editors.');
const client=new Client({name:'out-of-syllabus-validation',version:'0.1.0'});
const transport=new StdioClientTransport({command:process.execPath,args:[root+'/tools/godot-forge/dist/index.js','--project',root,'--godot',process.env.GODOT_PATH,'--launch','none'],stderr:'pipe'});
transport.stderr?.on('data',x=>process.stderr.write(x));

const reports=[];
async function call(name,args){const r=await client.callTool({name,arguments:args},undefined,{timeout:90000});reports.push({name,args,result:r.content.filter(x=>x.type!=='image')});console.log(name,JSON.stringify(reports.at(-1)).slice(0,5000));decode(r);return r;}
let failure;
try {
 await client.connect(transport);
 const connection=decode(await call('editor',{action:'connection'}));
 if(!connection.connected || path.resolve(connection.project_path).toLowerCase()!==root.toLowerCase()) throw Error('Wrong editor project');
 await call('scene',{action:'tree'});
 // Attach only to an already-running isolated QA game. Never restart or stop a user editor.
 const profile=decode(await call('game',{action:'eval',expression:'RuntimePaths.profile_id()'}));
 if(profile.value!==runId) throw Error('QA profile mismatch; game was not started with isolated data');
 await call('game',{action:'tree',depth:3});
 await call('input',{action:'send',steps:[{key:'Escape'},{action:'move_right',hold:0.25}]});
 assertMovement(await call('game',{action:'eval',expression:'session.player_position.x > 320'}));
 const screen=await call('view',{action:'game',max_size:1280});
 for(const c of screen.content) if(c.type==='image') fs.writeFileSync(path.join(reportsDir,'forge-game.png'),Buffer.from(c.data,'base64'));
 assertErrors(await call('run',{action:'errors'}));
 await call('editor',{action:'logs',limit:20});

}catch(error){failure=error;process.exitCode=1;console.error(error.stack||String(error));}
finally{
 try{await client.close();}catch(error){failure??=error;process.exitCode=1;}
 try{fs.writeFileSync(path.join(reportsDir,'forge.json'),JSON.stringify({project:root,runId,exitCode:process.exitCode||0,error:failure?.message,calls:reports},null,2));}catch(error){console.error(error);process.exitCode=1;}
}
