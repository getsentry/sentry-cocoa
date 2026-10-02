// AI-generated development aid for MetricKit Explorer, not a human-reviewed,
// verified source of correctness. Take its assumptions and coverage with a grain
// of salt, and independently validate important behavior.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

async function checkViewer(page, fixtures) {
  const assert = (condition, message) => { if (!condition) throw new Error(message); };
  const picker = page.getByLabel('JSON file', { exact: true });
  const dialog = page.getByRole('dialog', { name: 'Select application binaries', exact: true });
  const filter = page.getByRole('combobox', { name: 'Frame type', exact: true });
  const choose = async name => {
    await picker.setInputFiles(`${fixtures}/${name}`);
    await dialog.waitFor();
    await dialog.getByRole('button', { name: 'Continue', exact: true }).click();
  };
  assert(!await picker.evaluate(element => element.multiple), 'Only one report at a time');
  assert(await filter.inputValue() === 'all', 'Default to all frames');
  assert(!await page.locator('#invert').isChecked(), 'Default to top-down layout');
  await picker.setInputFiles(`${fixtures}/per-thread-flamegraph.json`);
  await dialog.waitFor();
  await dialog.getByRole('checkbox', { name: 'iOS-Swift', exact: true }).check();
  await dialog.getByRole('button', { name: 'Continue', exact: true }).click();
  assert(await page.locator('.frame.application').count() === 3, 'Application classification');
  const rects = await page.locator('.frame rect').evaluateAll(nodes => nodes.map(node => ({
    x: +node.getAttribute('x'), y: +node.getAttribute('y'), width: +node.getAttribute('width'),
  })));
  assert(Math.abs(rects[3].width / rects[2].width - 2) < .001, 'Proportional sample widths');
  assert(rects[0].y < rects[1].y && rects[1].y < rects[2].y, 'Root at top');
  await page.locator('#search').fill('0x3');
  assert(await page.locator('.frame.match').count() === 1, 'Address search');
  await page.locator('#search').fill('');
  await page.getByRole('button', { name: 'Zoom into iOS-Swift @ 0x3', exact: true }).focus();
  assert((await page.locator('#details').textContent()).includes('Samples: 2'), 'Focus details');
  await page.keyboard.press('Enter');
  assert(await page.locator('.frame').count() === 3, 'Keyboard branch zoom retains ancestors');
  await page.locator('#reset').click();
  await filter.selectOption('application');
  assert(await page.locator('.frame').count() === 3, 'Application filter');
  await filter.selectOption('system');
  assert(await page.locator('.frame').count() === 1, 'System filter');
  await filter.selectOption('all');
  await page.locator('summary').click();
  assert(await page.locator('#binary-list input:checked').count() === 1, 'Shared dialog/options selection');
  await page.locator('#invert').check();
  const inverted = await page.locator('.frame rect').evaluateAll(nodes => nodes.map(node => +node.getAttribute('y')));
  assert(inverted[0] > inverted[1], 'Inverted roots at bottom');
  await page.locator('#invert').uncheck();
  await page.locator('summary').click();

  const chart = page.locator('#chart');
  const before = await chart.evaluate(element => ({
    width: +element.querySelector('svg').getAttribute('width'),
    height: +element.querySelector('svg').getAttribute('height'),
  }));
  const wheel = values => chart.evaluate((element, values) => {
    const event = new WheelEvent('wheel', { bubbles: true, cancelable: true, clientX: 250, ...values });
    element.dispatchEvent(event);
    return event.defaultPrevented;
  }, values);
  assert(!await wheel({ deltaX: 100, deltaY: 100 }), 'Ordinary pan remains native');
  assert(await wheel({ ctrlKey: true, deltaY: -100 }), 'Pinch intercepts page zoom');
  await page.waitForFunction(width => +document.querySelector('#chart svg').getAttribute('width') > width, before.width);
  assert(+await page.locator('#chart svg').getAttribute('height') === before.height, 'Pinch changes width only');
  await page.locator('#reset').click();

  for (const name of ['not-per-thread-only-one-frame.json', 'not-per-thread.json', 'per-thread-nil-package.json', 'per-thread.json', 'tree-real.json', 'tree-unknown-fields.json']) {
    await choose(name);
    assert(await page.locator('.frame').count() > 0, `${name} renders`);
    assert(await page.locator('#status.error').count() === 0, `${name} has no error`);
    if (name === 'tree-real.json') assert(await page.locator('.stack').count() === 16, 'All fixture threads');
  }
  await picker.setInputFiles(`${fixtures}/tree-garbage.json`);
  await page.locator('#status.error').waitFor();
  assert(await page.locator('.frame').count() === 0, 'Invalid input clears frames');
  assert(!await dialog.isVisible(), 'Invalid input does not prompt for binaries');

  // Synthetic annotations keep browser tests independent of compiler output.
  await page.evaluate(async () => {
    const frame = { binaryName: 'App', binaryUUID: 'test', address: 4096, offsetIntoBinaryTextSegment: 16, sampleCount: 1,
      symbolication: { function: 'resolved_function', file: 'source files/fixture.c', line: 7 } };
    await load({ name: 'symbolicated.json', text: async () => JSON.stringify({ callStackTree: { callStacks: [{ callStackRootFrames: [frame] }] } }) });
  });
  await dialog.getByRole('checkbox', { name: 'App', exact: true }).check();
  await dialog.getByRole('button', { name: 'Continue', exact: true }).click();
  const resolved = page.getByRole('button', { name: 'Zoom into resolved_function', exact: true });
  await resolved.focus();
  const details = await page.locator('#details').textContent();
  assert(details.includes('source files/fixture.c:7') && details.includes('UUID: test'), 'Source and original metadata');
  for (const query of ['resolved_function', 'source files/fixture.c']) {
    await page.locator('#search').fill(query);
    assert(await page.locator('.frame.match').count() === 1, 'Symbol and source search');
  }
  await page.locator('#search').fill('');
  await page.evaluate(async () => {
    const frame = { binaryName: 'App', address: 4096, sampleCount: 1,
      symbolication: { function: '<img src=x onerror=alert(1)>', file: '<svg onload=alert(2)>', line: 42 } };
    await load({ name: 'safe-text.json', text: async () => JSON.stringify({ callStacks: [{ callStackRootFrames: [frame] }] }) });
  });
  await dialog.getByRole('button', { name: 'Continue', exact: true }).click();
  assert(await page.locator('#chart img').count() === 0, 'Untrusted names are text');
  assert((await page.locator('.frame title').textContent()).includes('<svg onload=alert(2)>:42'), 'Untrusted source paths are text');
  await page.evaluate(async () => {
    const frame = { binaryName: 'App', address: 4096, sampleCount: 1, symbolication: { function: 123, file: [], line: 'bad' } };
    await load({ name: 'malformed-annotations.json', text: async () => JSON.stringify({ callStacks: [{ callStackRootFrames: [frame] }] }) });
  });
  await dialog.getByRole('button', { name: 'Continue', exact: true }).click();
  assert(await page.getByRole('button', { name: 'Zoom into App @ 0x1000', exact: true }).count() === 1, 'Malformed annotations fall back to raw labels');
  return 'PASS: viewer fixtures, classification, filtering, inversion, search, details, zoom, scrolling, symbols, and safe text';
}

const tool = path.resolve(__dirname, '..');
const fixtures = path.resolve(tool, '../../Tests/Resources/MetricKitCallstacks');
const html = fs.readFileSync(path.join(tool, 'index.html'), 'utf8');
const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'metrickit-viewer-test-'));
const session = `metrickit-tests-${process.pid}`;
const log = path.join(temporary, 'playwright.log');
function cli(...args) {
  const result = spawnSync('playwright-cli', [`-s=${session}`, ...args], { cwd: temporary, encoding: 'utf8', timeout: 60000 });
  const output = (result.stdout || '') + (result.stderr || '');
  fs.appendFileSync(log, output);
  if (result.error || result.status !== 0 || /^### Error/m.test(output)) {
    throw new Error(`Playwright command failed: ${result.error?.message || args[0]}. See ${log}`);
  }
  return output;
}
let opened = false;
try {
  const script = path.join(temporary, 'check.js');
  fs.writeFileSync(script, `async page => {
    await page.setViewportSize({ width: 1280, height: 900 });
    await page.setContent(${JSON.stringify(html)});
    return await (${checkViewer.toString()})(page, ${JSON.stringify(fixtures)});
  }`);
  cli('open', 'about:blank');
  opened = true;
  const output = cli('run-code', `--filename=${script}`);
  const result = output.split('### Result\n')[1]?.split('\n')[0];
  if (!result?.startsWith('"PASS: viewer')) throw new Error(`Missing browser test result. See ${log}`);
  console.log(result);
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
} finally {
  if (opened) {
    try { cli('close'); } catch (error) { console.error(error.message); process.exitCode = 1; }
  }
  if (!process.exitCode) fs.rmSync(temporary, { recursive: true });
}
