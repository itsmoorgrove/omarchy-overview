const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const dir = path.resolve(__dirname, '..');
const qml = fs.readFileSync(path.join(dir, 'Overview.qml'), 'utf8');
function library(name) {
  const context = vm.createContext({});
  vm.runInContext(fs.readFileSync(path.join(dir, name), 'utf8').replace(/^\.pragma library\s*/m, ''), context);
  return context;
}
const Model = library('Model.js');
const Keybind = library('Keybind.js');
function setup(mode = 'delayed') {
  const writes = [];
  const timer = { running: false, restart() { this.running = true; }, stop() { this.running = false; } };
  const root = { pluginId: 'moorgrove.overview', entry: { id: 'moorgrove.overview', titles: true, wallpaper: true }, pendingSettings: {}, settingsCache: null };
  root.shell = { updateEntryInline(id, next) {
    writes.push(JSON.parse(JSON.stringify(next)));
    if (mode === 'throw') throw new Error('write failed');
    if (mode === 'reject') return false;
    if (mode === 'immediate') { root.entry = next; root.syncSettingsCache(); }
    return true;
  } };
  const context = vm.createContext({ root, Model, Keybind, settingsSyncTimeout: timer, console: { warn() {} } });
  // Evaluate the actual JavaScript function bodies in the changed QML file.
  const functions = [...qml.matchAll(/^  function (\w+)\([^\n]*\) \{[\s\S]*?^  \}/gm)];
  for (const match of functions) {
    vm.runInContext(match[0] + '\nroot.' + match[1] + ' = ' + match[1], context);
  }
  root.syncSettingsCache();
  return { root, writes, timer };
}
let passed = 0;
function test(name, run) { run(); passed++; console.log('PASS ' + name); }
test('all 19 supported values persist', () => {
  let count = 0;
  for (const [key, values] of Object.entries(Model.SETTING_VALUES)) {
    for (const value of values) {
      const { root, writes } = setup(); root.updateSetting(key, value);
      assert.equal(writes[0][key], value); assert.equal(root.setting(key), value); count++;
    }
  }
  assert.equal(count, 19);
});
test('shortcut apply and clear persist', () => {
  const { root, writes } = setup();
  root.updateSetting('shortcut', 'SUPER + O'); root.updateSetting('shortcut', '');
  assert.equal(writes[0].shortcut, 'SUPER + O'); assert.equal(writes[1].shortcut, '');
});
test('invalid values and non-string shortcuts never persist', () => {
  const { root, writes } = setup();
  for (const [key, value] of [['shortcut', 'SUPER + $(touch /tmp/bad)'], ['shortcut', null], ['shortcut', 4], ['titles', 'false'], ['slots', 999], ['unknown', true]]) root.updateSetting(key, value);
  assert.equal(writes.length, 0);
});
test('rapid consecutive changes preserve the first choice', () => {
  const { root, writes } = setup();
  root.updateSetting('titles', false); root.updateSetting('wallpaper', false);
  assert.equal(writes[1].titles, false); assert.equal(writes[1].wallpaper, false);
});
test('unrelated external changes survive while acknowledgement is pending', () => {
  const { root, writes } = setup(); root.updateSetting('titles', false);
  root.entry = { ...root.entry, density: 'large', externalMetadata: 42 }; root.syncSettingsCache();
  assert.equal(root.showTitles, false); assert.equal(root.density, 'large');
  root.updateSetting('wallpaper', false);
  assert.equal(writes[1].density, 'large'); assert.equal(writes[1].externalMetadata, 42);
});
test('acknowledgement tolerates normalized metadata', () => {
  const { root, writes, timer } = setup(); root.updateSetting('titles', false);
  root.entry = { ...writes[0], hostDefault: true }; root.syncSettingsCache();
  assert.equal(Object.keys(root.pendingSettings).length, 0); assert.equal(timer.running, false);
  assert.equal(root.settingsCache.hostDefault, true);
});
test('partial acknowledgements retain later pending values', () => {
  const { root, writes, timer } = setup();
  root.updateSetting('titles', false); root.updateSetting('wallpaper', false);
  root.entry = writes[0]; root.syncSettingsCache();
  assert.equal(root.showWallpaper, false); assert.equal(timer.running, true);
  assert.equal(Object.keys(root.pendingSettings).length, 1);
  root.entry = writes[1]; root.syncSettingsCache(); assert.equal(timer.running, false);
});
test('timeout recovers when acknowledgement never matches', () => {
  const { root } = setup(); root.updateSetting('titles', false);
  root.expirePendingSettings(); assert.equal(root.showTitles, true);
  root.entry = { ...root.entry, density: 'compact' }; root.syncSettingsCache();
  assert.equal(root.density, 'compact'); assert.equal(Object.keys(root.pendingSettings).length, 0);
});
test('failed and throwing writes restore published settings', () => {
  for (const mode of ['reject', 'throw']) {
    const { root, timer } = setup(mode); root.updateSetting('titles', false);
    assert.equal(root.showTitles, true); assert.equal(timer.running, false);
    assert.equal(Object.keys(root.pendingSettings).length, 0);
  }
});
test('synchronous acknowledgement stops the timer', () => {
  const { root, timer } = setup('immediate'); root.updateSetting('titles', false);
  assert.equal(root.showTitles, false); assert.equal(timer.running, false);
});
assert.match(qml, /interval: 2000\s+repeat: false\s+onTriggered: root\.expirePendingSettings\(\)/);
console.log(passed + ' tests passed');
