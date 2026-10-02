import {Client} from './godot-forge/node_modules/@modelcontextprotocol/sdk/dist/esm/client/index.js';
import {StdioClientTransport} from './godot-forge/node_modules/@modelcontextprotocol/sdk/dist/esm/client/stdio.js';
import fs from 'node:fs';
const root='E:/my_code/Out-of-Syllabus';
const client=new Client({name:'out-of-syllabus-validation',version:'0.1.0'});
const transport=new StdioClientTransport({command:'D:/nodejs/node.exe',args:[root+'/tools/godot-forge/dist/index.js','--project',root,'--godot','D:/Godot_v4.7.2/Godot_v4.7.2-stable_win64.exe','--launch','gui'],stderr:'pipe'});
transport.stderr?.on('data',x=>process.stderr.write(x));
await client.connect(transport);
const reports=[];
async function call(name,args){const r=await client.callTool({name,arguments:args},undefined,{timeout:90000});reports.push({name,args,result:r.content.filter(x=>x.type!=='image')});console.log(name,JSON.stringify(reports.at(-1)).slice(0,5000));return r;}
try {
 await call('editor',{action:'restart',save:true});
 await new Promise(r=>setTimeout(r,5000));
 await call('scene',{action:'tree'});
 await call('run',{action:'play',scene:'main',restart:true,timeout:30,mute:true});
 await call('game',{action:'tree',depth:3});
 await call('input',{action:'send',steps:[{key:'Escape'},{action:'move_right',hold:0.25}]});
 await call('game',{action:'eval',expression:'session.player_position.x > 320'});
 const screen=await call('view',{action:'game',max_size:1280});
 for(const c of screen.content) if(c.type==='image') fs.writeFileSync(root+'/reports/forge-game.png',Buffer.from(c.data,'base64'));
 await call('run',{action:'errors'});
 await call('editor',{action:'logs',limit:20});
 await call('run',{action:'stop'});
}finally{fs.writeFileSync(root+'/reports/forge.json',JSON.stringify(reports,null,2));await client.close();}
