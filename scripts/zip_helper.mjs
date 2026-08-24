import { createRequire } from 'module';
import fs from 'fs';
const require = createRequire(import.meta.url);
const { ZipArchive } = require('archiver');

const output = fs.createWriteStream('starcade-web.zip');
const archive = new ZipArchive('zip', { zlib: { level: 9 } });

output.on('close', () => {
  const sizeMB = (archive.pointer() / 1024 / 1024).toFixed(1);
  console.log('Created starcade-web.zip (' + sizeMB + ' MB)');
});

archive.on('error', (err) => { throw err; });
archive.pipe(output);
archive.directory('build/web/', false);
archive.finalize();
