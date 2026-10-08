#!/usr/bin/env node
// Offline contract probe. Imports reviewed package code; never uses live runtime files or HTTP.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const args = process.argv.slice(2);
const options = {};
for (let i = 0; i < args.length; i += 2) {
  if (!['--package-dir', '--expected-version'].includes(args[i]) || !args[i + 1]) {
    console.error('Usage: node scripts/check-openchamber-contract.mjs --package-dir PACKAGE [--expected-version VERSION]');
    process.exit(2);
  }
  options[args[i]] = args[i + 1];
}
if (!options['--package-dir']) {
  console.error('An explicit --package-dir is required (reviewed installed or unpacked @openchamber/web).');
  process.exit(2);
}

let stage = 'package identity and version';
try {
  const packageDir = path.resolve(options['--package-dir']);
  const document = JSON.parse(await readFile(path.join(root, 'home/dot_config/dotfiles/openchamber-workflow-defaults.json'), 'utf8'));
  const pkg = JSON.parse(await readFile(path.join(packageDir, 'package.json'), 'utf8'));
  assert.equal(pkg.name, '@openchamber/web');
  if (options['--expected-version']) assert.equal(pkg.version, options['--expected-version']);
  else assert.ok(document.openchamberVersions.includes(pkg.version), 'package version is not reviewed');
  const lib = path.join(packageDir, 'server/lib/opencode');
  const load = (name) => import(pathToFileURL(path.join(lib, name)).href);
  stage = 'workflow field registry';
  const registry = JSON.parse(await readFile(path.join(lib, 'settings-registry.json'), 'utf8'));
  for (const key of Object.keys(document.settings)) {
    const field = registry.fields[key];
    assert.ok(field && !field.secret && !field.computed && !field.local && !field.perSurface, `registry changed: ${key}`);
    assert.equal(field.scope, key === 'permissionDefaultMode' ? 'instance' : 'profile');
  }
  stage = 'sanitizer accepts defaults and rejects invalid values';
  const { createSettingsHelpers } = await load('settings-helpers.js');
  const helpers = createSettingsHelpers({
    normalizeStringArray: (value) => Array.isArray(value) ? value : [],
    normalizeManagedRemoteTunnelPresets: () => undefined,
    normalizeManagedRemoteTunnelPresetTokens: () => undefined,
    sanitizeModelRefs: () => undefined,
    sanitizeSkillCatalogs: () => undefined,
    sanitizeProjects: (value) => value,
  });
  assert.deepEqual(helpers.sanitizeSettingsUpdate(document.settings), document.settings, 'sanitizer drops/changes a workflow default');
  assert.deepEqual(helpers.sanitizeSettingsUpdate({
    sessionGoalMaxAutoTurns: 201, sessionGoalDefaultBudget: 0,
    notificationMode: 'invalid', permissionDefaultMode: 'invalid',
  }), {}, 'invalid values must be rejected');
  stage = 'settings module imports';
  const filesModule = await load('settings-files.js');
  const { createSettingsRuntime } = await load('settings-runtime.js');
  const { registerOpenCodeRoutes } = await load('routes.js');
  const settingsPath = '/contract-fixture/settings.json';
  const preferencesPath = '/contract-fixture/preferences.json';
  const unrelated = { projects: [], desktopUiPassword: 'nonsecret-test-fixture', themeId: 'fixture-theme', unknownRuntimeFact: { keep: true } };
  const files = new Map([[settingsPath, JSON.stringify(unrelated)]]);
  const missing = () => Object.assign(new Error('fixture absent'), { code: 'ENOENT' });
  const fsPromises = {
    readFile: async (name) => { if (!files.has(name)) throw missing(); return files.get(name); },
    mkdir: async () => undefined,
    writeFile: async (name, data) => { files.set(name, data); },
    rename: async (from, to) => { files.set(to, files.get(from)); files.delete(from); },
    chmod: async () => {},
    rm: async (name) => { files.delete(name); },
    readdir: async () => [],
  };
  const runtime = createSettingsRuntime({
    fsPromises, path, crypto, SETTINGS_FILE_PATH: settingsPath,
    sanitizeSettingsUpdate: helpers.sanitizeSettingsUpdate,
    mergePersistedSettings: helpers.mergePersistedSettings,
    formatSettingsResponse: helpers.formatSettingsResponse,
    sanitizeProjects: (projects) => projects || [],
    normalizeSettingsPaths: (settings) => ({ settings, changed: false }),
    normalizeStringArray: (values) => values || [],
    resolveDirectoryCandidate: () => null,
  });
  const routes = new Map();
  const app = Object.fromEntries(['get', 'put', 'post', 'delete', 'use'].map((method) => [method, (route, ...handlers) => {
    routes.set(`${method.toUpperCase()} ${route}`, handlers.at(-1));
  }]));
  stage = 'settings route registration';
  registerOpenCodeRoutes(app, { ...runtime, formatSettingsResponse: helpers.formatSettingsResponse });
  const invoke = async (method, body) => {
    const handler = routes.get(`${method} /api/config/settings`);
    assert.equal(typeof handler, 'function', `${method} route missing`);
    let result;
    const res = { json: (value) => { result = value; }, status: (code) => { assert.equal(code, 200); return res; } };
    await handler({ body, query: {}, get: () => undefined }, res);
    assert.ok(result && typeof result === 'object');
    return result;
  };
  stage = 'GET/PUT settings round trip with in-memory filesystem';
  await invoke('GET');
  const applied = await invoke('PUT', document.settings);
  for (const [key, value] of Object.entries(document.settings)) assert.deepEqual(applied[key], value);
  const verified = await invoke('GET');
  for (const [key, value] of Object.entries(document.settings)) assert.deepEqual(verified[key], value);
  assert.equal(verified.desktopUiPassword, undefined);
  stage = 'unrelated settings preservation';
  const stored = JSON.parse(files.get(settingsPath));
  for (const [key, value] of Object.entries(unrelated)) assert.deepEqual(stored[key], value, `unrelated field lost: ${key}`);
  stage = 'profile split and timestamp preservation';
  const preferences = JSON.parse(files.get(preferencesPath));
  assert.equal(preferences.version, 1);
  assert.equal(preferences.fields.permissionDefaultMode, undefined);
  for (const [key, value] of Object.entries(document.settings)) {
    if (key === 'permissionDefaultMode') continue;
    assert.deepEqual(preferences.fields[key].value, value);
    assert.ok(preferences.fields[key].updatedAt > 0);
  }
  await invoke('PUT', document.settings);
  assert.deepEqual(JSON.parse(files.get(preferencesPath)), preferences, 'unchanged preferences must retain timestamps');
  assert.equal(filesModule.parsePreferencesDocument(files.get(preferencesPath)).ok, true);
  stage = 'response defaults and secret redaction';
  const formatted = helpers.formatSettingsResponse({ ...document.settings, desktopUiPassword: unrelated.desktopUiPassword });
  assert.equal(formatted.desktopUiPassword, undefined, 'secret must not be returned');
  for (const [key, value] of Object.entries(document.settings)) assert.deepEqual(formatted[key], value);
  stage = 'version endpoint source signature';
  const coreRoutes = await readFile(path.join(lib, 'core-routes.js'), 'utf8');
  assert.match(coreRoutes, /app\.get\('\/api\/version',[\s\S]{0,500}res\.json\(\{[\s\S]{0,200}openchamberVersion,/);
  stage = 'inert project and disabled loop example formats';
  const projectModule = await import(pathToFileURL(path.join(packageDir, 'server/lib/projects/project-setup.js')).href);
  const project = projectModule.parseSharedProjectConfig(await readFile(path.join(root, 'docs/examples/openchamber/project.json'), 'utf8'));
  assert.equal(project.status, 'ok');
  assert.equal(project.config.projectActions.length, 1);
  const loopsModule = await import(pathToFileURL(path.join(packageDir, 'server/lib/scheduled-tasks/loops.js')).href);
  const loop = loopsModule.parseLoopDefinition(path.join(root, 'docs/examples/openchamber/review-changes.md'));
  assert.ok(loop);
  assert.equal(loop.enabled, false);
  assert.equal(loop.execution.goalEnabled, undefined);
  console.log(`OpenChamber ${pkg.version} contract passed: routes, defaults, sanitization, merge, preference timestamps, response redaction, inert examples.`);
  if (!document.openchamberVersions.includes(pkg.version)) {
    console.log('Candidate probe only: this version is NOT approved by the workflow apply tool. Review before changing its allowlists.');
  }
} catch {
  // Do not echo arbitrary package exception text or local paths.
  console.error(`OpenChamber contract failed at: ${stage}. Review the internal implementation; do not apply defaults.`);
  process.exit(1);
}
