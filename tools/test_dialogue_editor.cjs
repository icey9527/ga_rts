const fs = require('fs');
const vm = require('vm');
const path = require('path');

const html = fs.readFileSync(path.join(__dirname, 'dialogue_editor.html'), 'utf8');
const script = html.match(/<script>([\s\S]*)<\/script>/)[1];
const sandbox = { window: {}, console };
vm.runInNewContext(script, sandbox, { filename: 'dialogue_editor.html' });
const api = sandbox.window.DialogueEditor;
if (!api) throw new Error('DialogueEditor test API missing');

const source = fs.readFileSync(path.join(__dirname, '..', 'teams', 'moon', 'chara', '026', 'dialogue.lua'), 'utf8');
const tree = api.parseLua(source);
if (!tree || tree.t !== 'table') throw new Error('dialogue did not parse as table');
const friendly = tree.e.find(x => x.k === 'friendly')?.v;
const attack = friendly?.e.find(x => x.k === 'attack')?.v;
if (!attack || attack.t !== 'table' || attack.e.length < 1) throw new Error('friendly.attack list missing');
const first = attack.e[0];
if (typeof first.v !== 'string' || !first.v.includes('火力')) throw new Error('first attack line mismatch');
first.v = '测试台词 {opponent_commander}';
const output = 'return ' + api.serialize(tree) + '\n';
const reparsed = api.parseLua(output);
const reparsedFriendly = reparsed.e.find(x => x.k === 'friendly')?.v;
const reparsedAttack = reparsedFriendly?.e.find(x => x.k === 'attack')?.v;
if (reparsedAttack?.e[0]?.v !== '测试台词 {opponent_commander}') throw new Error('round-trip changed dialogue text');

const fake = {
  cfg: { face_attack: 'face/fac026_attack.agi.png', face_idle: 'face/fac026_idle.agi.png' },
  faceMap: new Map([['fac026_0000.agi.png', {}], ['fac026_attack.agi.png', {}], ['fac026_0008.agi.png', {}]])
};
if (api.avatarFile(fake, 'attack') !== 'fac026_attack.agi.png') throw new Error('explicit attack face was not selected');
if (api.avatarFile(fake, 'hit') !== 'fac026_0008.agi.png') throw new Error('wanted hit face was not selected');

const advisorSource = fs.readFileSync(path.join(__dirname, '..', 'teams', 'moon', 'advisor', 'dialogue.lua'), 'utf8');
const advisor = api.parseLua(advisorSource);
const groups = advisor.e.find(x => x.k === 'groups')?.v;
const scenes = advisor.e.find(x => x.k === 'scenes')?.v;
if (!groups || groups.t !== 'table' || !groups.e.length) throw new Error('advisor groups missing');
if (!scenes || scenes.t !== 'table' || !scenes.e[0]?.v?.e?.length) throw new Error('advisor scenes missing');
const advisorRoundTrip = api.parseLua('return ' + api.serialize(advisor));
if (!advisorRoundTrip.e.find(x => x.k === 'groups')) throw new Error('advisor round-trip lost groups');

console.log('PASS: dialogue editor parser, serializer, placeholders, and runtime face mapping');
