import { readdirSync, statSync, mkdirSync, copyFileSync, existsSync } from 'fs';
import { join, dirname, basename, extname, relative } from 'path';
import sharp from 'sharp';

const BASE_DIR = 'D:\\Fastkirana';
const SKIP_DIRS = new Set(['node_modules', '.next', 'build', '__pycache__', '.git', 'web']);

function collectFiles(dir, files = []) {
  try {
    const entries = readdirSync(dir);
    for (const entry of entries) {
      const fullPath = join(dir, entry);
      try {
        const stat = statSync(fullPath);
        if (stat.isDirectory()) {
          const name = basename(entry);
          if (!SKIP_DIRS.has(name)) {
            collectFiles(fullPath, files);
          }
        } else if (stat.isFile()) {
          const ext = extname(entry).toLowerCase();
          if (ext === '.png') {
            files.push(fullPath);
          }
        }
      } catch (e) {
        // permission denied, skip
      }
    }
  } catch (e) {
    console.warn(`Cannot read dir: ${dir}`);
  }
  return files;
}

async function convertToWebP(pngPath) {
  const webpPath = pngPath.replace(/\.png$/i, '.webp');

  // Skip if WebP already exists
  if (existsSync(webpPath)) {
    console.log(`[SKIP] WebP already exists: ${relative(BASE_DIR, webpPath)}`);
    return { png: pngPath, webp: webpPath, skipped: true };
  }

  try {
    const info = await sharp(pngPath).metadata();
    const pngSize = statSync(pngPath).size;

    await sharp(pngPath)
      .webp({
        quality: 82,
        effort: 4,
        lossless: false,
      })
      .toFile(webpPath);

    const webpSize = statSync(webpPath).size;
    const savings = Math.round((1 - webpSize / pngSize) * 100);

    console.log(`[DONE] ${relative(BASE_DIR, pngPath)} → ${relative(BASE_DIR, webpPath)} (${pngSize}→${webpSize} bytes, ${savings}% smaller)`);
    return { png: pngPath, webp: webpPath, savings };
  } catch (e) {
    console.error(`[FAIL] ${relative(BASE_DIR, pngPath)}: ${e.message}`);
    return { png: pngPath, error: e.message };
  }
}

async function main() {
  console.log('Scanning for PNG files...\n');

  // Scan public/ and assets/
  const dirs = [
    join(BASE_DIR, 'public'),
    join(BASE_DIR, 'fastkirana_flutter', 'assets'),
  ];

  let allPngs = [];
  for (const dir of dirs) {
    if (existsSync(dir)) {
      const found = collectFiles(dir);
      console.log(`Found ${found.length} PNG files in ${relative(BASE_DIR, dir)}/`);
      allPngs.push(...found);
    }
  }

  console.log(`\nTotal PNG files to convert: ${allPngs.length}\n`);
  console.log('Starting WebP conversion...\n');

  let converted = 0;
  let skipped = 0;
  let failed = 0;

  for (const pngPath of allPngs) {
    const result = await convertToWebP(pngPath);
    if (result.skipped) skipped++;
    else if (result.error) failed++;
    else converted++;
  }

  console.log(`\n=== Summary ===`);
  console.log(`Converted: ${converted}`);
  console.log(`Skipped (already exists): ${skipped}`);
  console.log(`Failed: ${failed}`);
  console.log(`Total: ${allPngs.length}`);
}

main().catch(e => console.error('Fatal error:', e));
