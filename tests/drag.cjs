const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const dir = path.resolve(__dirname, '..');

const context = vm.createContext({});
vm.runInContext(fs.readFileSync(path.join(dir, 'Model.js'), 'utf8').replace(/^\.pragma library\s*/m, ''), context);
const Model = context;

let passed = 0;
function test(name, fn) {
  fn();
  passed++;
  console.log('PASS ' + name);
}

const left = { x: 0, y: 0, width: 1920, height: 1080 };
const right = { x: 1920, y: 0, width: 1920, height: 1080 };
const a = '0x55a67fb21f60';
const b = '0x55a6809c92b0';

test('a point is assigned to the monitor that contains it', () => {
  assert.equal(Model.frameIndexAt([left, right], 10, 10), 0);
  assert.equal(Model.frameIndexAt([left, right], 1919, 1079), 0);
  assert.equal(Model.frameIndexAt([left, right], 1920, 0), 1);
  assert.equal(Model.frameIndexAt([left, right], 3000, 500), 1);
});

test('points outside every monitor, and missing frames, match nothing', () => {
  assert.equal(Model.frameIndexAt([left, right], 3840, 10), -1);
  assert.equal(Model.frameIndexAt([left, right], -1, 10), -1);
  assert.equal(Model.frameIndexAt([null, right], 10, 10), -1);
  assert.equal(Model.frameIndexAt([left], NaN, 10), -1);
  assert.equal(Model.frameIndexAt(null, 10, 10), -1);
});

test('a monitor placed above another is found by its vertical offset', () => {
  const top = { x: 0, y: -1080, width: 1920, height: 1080 };
  assert.equal(Model.frameIndexAt([left, top], 100, -10), 1);
});

test('a window dropped on another workspace moves without following it', () => {
  const commands = Model.moveCommands([a], { id: 2, special: false }, { id: 12, special: false });
  assert.deepEqual(Array.from(commands), [
    'hl.dsp.window.move({ window = "address:' + a + '", workspace = "12", follow = false })'
  ]);
});

test('a dragged workspace moves every one of its windows', () => {
  const commands = Model.moveCommands([a, b], { id: 3, special: false }, { id: 13, special: false });
  assert.equal(commands.length, 2);
  assert.match(commands[1], new RegExp('address:' + b + '".*workspace = "13"'));
});

test('dropping back onto the source workspace does nothing', () => {
  assert.equal(Model.moveCommands([a], { id: 3, special: false }, { id: 3, special: false }).length, 0);
  assert.equal(Model.moveCommands([a], { id: -98, special: true, label: 'magic' },
    { id: -98, special: true, label: 'magic' }).length, 0);
});

test('special workspaces are targeted by name', () => {
  const commands = Model.moveCommands([a], { id: 1, special: false }, { id: -98, special: true, label: 'magic' });
  assert.match(commands[0], /workspace = "special:magic"/);
});

test('no target, malformed addresses and malformed targets produce no command', () => {
  assert.equal(Model.moveCommands([a], { id: 1, special: false }, null).length, 0);
  assert.equal(Model.moveCommands(['0xZZ', 'address:0x1"), os.exit()'], { id: 1, special: false },
    { id: 2, special: false }).length, 0);
  assert.equal(Model.moveCommands([a], { id: 1, special: false }, { id: '2"); x("', special: false }).length, 0);
  assert.equal(Model.moveCommands([a], { id: 1, special: false },
    { id: -1, special: true, label: 'bad name"' }).length, 0);
});

test('slots compare by workspace id or special name', () => {
  assert.equal(Model.sameSlot({ id: 4, special: false }, { id: '4', special: false }), true);
  assert.equal(Model.sameSlot({ id: 4, special: false }, { id: 14, special: false }), false);
  assert.equal(Model.sameSlot({ id: -98, special: true, label: 'x' }, { id: 4, special: false }), false);
  assert.equal(Model.sameSlot(null, { id: 4, special: false }), false);
});

// Two monitors with Hyprland rules binding 1-10 left and 11-20 right, as a
// "linked workspaces" setup does.
const rules = [];
for (let i = 1; i <= 20; i++) rules.push({ workspaceString: String(i), monitor: i <= 10 ? 'HDMI-A-1' : 'DP-2', enabled: true });
const hdmi = { name: 'HDMI-A-1' };
const dp = { name: 'DP-2' };
function workspaces(list) {
  return { values: list.map(([id, monitor]) => ({ id, name: String(id), monitor })) };
}
function ids(slots) { return Array.from(slots, (slot) => slot.id); }
function emptyIds(slots) { return Array.from(slots).filter((slot) => !slot.workspace).map((slot) => slot.id); }

test('workspace rules are grouped per monitor, ascending, without selectors or named workspaces', () => {
  const bound = Model.boundWorkspaceIds(rules.concat([
    { workspaceString: 'r[1-5]', monitor: 'DP-2' },
    { workspaceString: 'name:mail', monitor: 'DP-2' },
    { workspaceString: '30', monitor: 'desc:Dell U2720Q' },
    { workspaceString: '31', monitor: 'DP-2', enabled: false },
    { workspaceString: '2', monitor: 'HDMI-A-1' }
  ]));
  assert.deepEqual(Array.from(bound['HDMI-A-1']), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
  assert.deepEqual(Array.from(bound['DP-2']), [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]);
  assert.equal(Object.keys(bound).length, 2);
  assert.deepEqual(Object.keys(Model.boundWorkspaceIds(null)), []);
});

test('each monitor offers empty workspaces from its own range, focused or not', () => {
  const bound = Model.boundWorkspaceIds(rules);
  const ws = workspaces([[1, hdmi], [2, hdmi], [3, hdmi], [11, dp], [14, dp]]);
  const options = { minSlots: 3, showEmpty: true, boundIds: bound };
  const left = Model.slotsFor(ws, 'HDMI-A-1', true, options);
  const right = Model.slotsFor(ws, 'DP-2', false, options);
  assert.deepEqual(ids(left), [1, 2, 3, 4]);
  assert.deepEqual(emptyIds(left), [4]);
  assert.deepEqual(ids(right), [11, 12, 13, 14, 15]);
  assert.deepEqual(emptyIds(right), [12, 13, 15]);
});

test('the minimum slot count is honoured within a monitor range', () => {
  const bound = Model.boundWorkspaceIds(rules);
  const ws = workspaces([[11, dp]]);
  const right = Model.slotsFor(ws, 'DP-2', false, { minSlots: 5, showEmpty: true, boundIds: bound });
  assert.deepEqual(ids(right), [11, 12, 13, 14, 15]);
});

test('an id in use on the other monitor is never offered as empty', () => {
  const bound = Model.boundWorkspaceIds(rules);
  // workspace 12 was moved onto the left monitor by hand
  const ws = workspaces([[1, hdmi], [12, hdmi], [11, dp]]);
  const right = Model.slotsFor(ws, 'DP-2', true, { minSlots: 3, showEmpty: true, boundIds: bound });
  assert.deepEqual(emptyIds(right), [13]);
});

test('without rules the focused monitor keeps the classic 1-10 empty slots', () => {
  const ws = workspaces([[1, hdmi], [2, hdmi], [11, dp]]);
  const focused = Model.slotsFor(ws, 'HDMI-A-1', true, { minSlots: 5, showEmpty: true, boundIds: {} });
  const other = Model.slotsFor(ws, 'DP-2', false, { minSlots: 5, showEmpty: true, boundIds: {} });
  assert.deepEqual(ids(focused), [1, 2, 3, 4, 5]);
  assert.deepEqual(ids(other), [11]);
});

test('classic empty slots skip numbers a rule pins to another monitor', () => {
  const bound = { 'DP-2': [3, 4] };
  const ws = workspaces([[1, hdmi]]);
  const focused = Model.slotsFor(ws, 'HDMI-A-1', true, { minSlots: 5, showEmpty: true, boundIds: bound });
  assert.deepEqual(ids(focused), [1, 2, 5]);
});

test('empty slots stay off when the setting is off', () => {
  const bound = Model.boundWorkspaceIds(rules);
  const ws = workspaces([[1, hdmi], [11, dp]]);
  assert.deepEqual(ids(Model.slotsFor(ws, 'DP-2', true, { minSlots: 5, showEmpty: false, boundIds: bound })), [11]);
});

console.log(passed + ' tests passed');
