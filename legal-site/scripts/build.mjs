import { existsSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { cp, mkdir, readFile, readdir, rm, writeFile } from 'node:fs/promises';
import { extname, join, relative, resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const source = join(root, 'src');
const destination = join(root, 'dist');

if (existsSync(join(root, '.env'))) {
  const lines = (await readFile(join(root, '.env'), 'utf8')).split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const separator = trimmed.indexOf('=');
    if (separator < 1) continue;
    const key = trimmed.slice(0, separator).trim();
    const value = trimmed.slice(separator + 1).trim().replace(/^['"]|['"]$/g, '');
    if (!(key in process.env)) process.env[key] = value;
  }
}

const required = [
  'LEGAL_OPERATOR_NAME',
  'LEGAL_SUPPORT_EMAIL',
  'LEGAL_POSTAL_ADDRESS',
  'LEGAL_GRIEVANCE_NAME',
  'LEGAL_GRIEVANCE_EMAIL',
  'LEGAL_GOVERNING_JURISDICTION',
  'PUBLIC_SITE_URL',
  'APP_DOWNLOAD_URL',
  'APP_VERSION',
  'APP_APK_SIZE',
  'APP_APK_SHA256',
  'APP_MIN_ANDROID',
];

const missing = required.filter((key) => !process.env[key]?.trim());
if (missing.length) {
  throw new Error(`Missing required legal-site settings: ${missing.join(', ')}`);
}

const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
for (const key of ['LEGAL_SUPPORT_EMAIL', 'LEGAL_GRIEVANCE_EMAIL']) {
  if (!emailPattern.test(process.env[key])) throw new Error(`${key} is not a valid email address`);
}

const publicUrl = new URL(process.env.PUBLIC_SITE_URL);
if (publicUrl.protocol !== 'https:') throw new Error('PUBLIC_SITE_URL must use HTTPS');

const downloadUrl = new URL(process.env.APP_DOWNLOAD_URL);
if (downloadUrl.protocol !== 'https:') throw new Error('APP_DOWNLOAD_URL must use HTTPS');

const checksum = process.env.APP_APK_SHA256.trim().toLowerCase();
if (!/^[a-f0-9]{64}$/.test(checksum)) {
  throw new Error('APP_APK_SHA256 must be the 64-character SHA-256 checksum of the published APK');
}

const values = {
  LEGAL_OPERATOR_NAME: process.env.LEGAL_OPERATOR_NAME,
  LEGAL_SUPPORT_EMAIL: process.env.LEGAL_SUPPORT_EMAIL,
  LEGAL_POSTAL_ADDRESS: process.env.LEGAL_POSTAL_ADDRESS,
  LEGAL_GRIEVANCE_NAME: process.env.LEGAL_GRIEVANCE_NAME,
  LEGAL_GRIEVANCE_EMAIL: process.env.LEGAL_GRIEVANCE_EMAIL,
  LEGAL_GOVERNING_JURISDICTION: process.env.LEGAL_GOVERNING_JURISDICTION,
  PUBLIC_SITE_URL: publicUrl.toString().replace(/\/$/, ''),
  APP_DOWNLOAD_URL: downloadUrl.toString(),
  APP_VERSION: process.env.APP_VERSION,
  APP_APK_SIZE: process.env.APP_APK_SIZE,
  APP_APK_SHA256: checksum,
  APP_MIN_ANDROID: process.env.APP_MIN_ANDROID,
};

const versionedAssets = new Map();
for (const assetPath of ['/assets/styles.css', '/assets/site.js']) {
  const sourcePath = join(source, assetPath.replace(/^\//, ''));
  const digest = createHash('sha256')
    .update(await readFile(sourcePath))
    .digest('hex')
    .slice(0, 12);
  versionedAssets.set(assetPath, `${assetPath}?v=${digest}`);
}

function escapeHtml(value) {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}

function render(content) {
  let rendered = content;
  for (const [key, value] of Object.entries(values)) {
    rendered = rendered.replaceAll(`{{${key}}}`, escapeHtml(value));
    rendered = rendered.replaceAll(`{{${key}_URL}}`, encodeURIComponent(value));
  }
  for (const [assetPath, versionedPath] of versionedAssets) {
    rendered = rendered.replaceAll(assetPath, versionedPath);
  }
  const unresolved = rendered.match(/\{\{[A-Z0-9_]+\}\}/g);
  if (unresolved) throw new Error(`Unresolved template values: ${[...new Set(unresolved)].join(', ')}`);
  return rendered;
}

async function filesIn(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) files.push(...await filesIn(path));
    else files.push(path);
  }
  return files;
}

await rm(destination, { recursive: true, force: true });
await mkdir(destination, { recursive: true });

for (const input of await filesIn(source)) {
  const output = join(destination, relative(source, input));
  await mkdir(resolve(output, '..'), { recursive: true });
  const extension = extname(input);
  if (['.html', '.xml', '.txt'].includes(extension) || input.endsWith('_headers')) {
    await writeFile(output, render(await readFile(input, 'utf8')), 'utf8');
  } else {
    await cp(input, output);
  }
}

console.log(`Built Hi PG legal site for ${values.PUBLIC_SITE_URL}`);
