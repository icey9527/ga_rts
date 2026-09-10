// Tests the exact inline application code with temporary File System Access handles.
const fs = require('node:fs/promises');
const path = require('node:path');
const os = require('node:os');
const vm = require('node:vm');
const assert = require('node:assert/strict');
class Directory {
  constructor(location) { this.location=location; this.name=path.basename(location); this.kind='directory'; }
  async getDirectoryHandle(name) {
    const location=path.join(this.location,name);
    try { if (!(await fs.stat(location)).isDirectory()) throw Error('not a directory'); }
    catch (e) { if(e.code==='ENOENT') e.name='NotFoundError'; throw e; }
    return new Directory(location);
  }
  async getFileHandle(name, options={}) {
    const location=path.join(this.location,name);
    try { await fs.access(location); } catch(e) {
      if(options.create) await fs.writeFile(location,''); else {e.name='NotFoundError';throw e;}
    }
    return new FileHandle(location);
  }
  async *values() {
    for (const item of await fs.readdir(this.location,{withFileTypes:true}))
      yield item.isDirectory()?new Directory(path.join(this.location,item.name)):new FileHandle(path.join(this.location,item.name));
  }
}
class FileHandle {
  constructor(location) { this.location=location;this.name=path.basename(location);this.kind='file'; }
  async getFile() { const data=await fs.readFile(this.location);return {arrayBuffer:async()=>data}; }
  async createWritable() {
    let output;
    return {write:async value=>{output=value;},close:async()=>fs.writeFile(this.location,output),abort:async()=>{}};
  }
}
(async()=>{
  const html=await fs.readFile(path.join(__dirname,'face_editor.html'),'utf8');
  assert(!/fetch\(|src="\/|http:\/\/localhost/.test(html),'standalone HTML has no server dependency');
  const script=html.match(/<script>([\s\S]*?)<\/script>/)[1];
  const context=vm.createContext({TextDecoder});
  new vm.Script(script+'\nthis.api={scanTeams,saveAssignment,parseChara,updateChara};').runInContext(context);
  const api=context.api;
  const root=await fs.mkdtemp(path.join(os.tmpdir(),'rts-face-test-'));
  try {
    const base=path.join(root,'test/chara/010'),skin=path.join(root,'test/skins/red/chara/010');
    for(const folder of [base,skin]) {
      await fs.mkdir(path.join(folder,'face'),{recursive:true});
      await fs.writeFile(path.join(folder,'face/a.png'),'test');
    }
    const original='\uFEFF[chara]\r\nid=10\r\nname=测试\r\n[skill]\r\ntype=beam\r\n';
    await fs.writeFile(path.join(base,'chara.tbl'),original);
    let entries=await api.scanTeams(new Directory(root));
    const variant=entries.find(c=>c.skin==='red');
    assert.equal(variant.cid,'010');assert.equal(variant.name,'测试');
    await api.saveAssignment(variant,{normal:'a.png'});
    assert.equal(await fs.readFile(path.join(base,'chara.tbl'),'utf8'),original,'skin never edits base');
    assert.equal(api.parseChara(await fs.readFile(path.join(skin,'chara.tbl'),'utf8')).face_normal,'face/a.png');
    const primary=entries.find(c=>!c.skin);
    await api.saveAssignment(primary,{hit:'a.png'});
    let saved=await fs.readFile(path.join(base,'chara.tbl'),'utf8');
    assert(saved.startsWith('\uFEFF'));assert(saved.includes('[skill]\r\ntype=beam'));
    assert.equal(api.parseChara(saved).face_hit,'face/a.png');
    entries=await api.scanTeams(new Directory(root));
    assert.equal(entries.find(c=>!c.skin).assign.hit,'a.png','assignment survives reload');
    await fs.appendFile(path.join(base,'chara.tbl'),'external=1\r\n');
    await assert.rejects(()=>api.saveAssignment(primary,{}),/其他窗口/);
    await assert.rejects(()=>api.saveAssignment(variant,{normal:'../bad.png'}),/不属于/);
    await api.saveAssignment(variant,{});
    assert(!api.parseChara(await fs.readFile(path.join(skin,'chara.tbl'),'utf8')).face_normal,'clear removes override');
    console.log('PASS: standalone script syntax, scan, skin isolation, save/reload, BOM/sections, conflict and clear');
  } finally { await fs.rm(root,{recursive:true,force:true}); }
})().catch(error=>{console.error(error);process.exitCode=1;});
