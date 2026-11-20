import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Resvg } from '@resvg/resvg-js';
import { PNG } from 'pngjs';

const root = fileURLToPath(new URL('../../', import.meta.url));
const source = path.join(root, 'brand/news.dev/app-icon.svg');
const svg = fs.readFileSync(source, 'utf8');

function render(relativePath, size, opaque = false) {
  const png = new Resvg(svg, { fitTo: { mode: 'width', value: size } }).render().asPng();
  const pixels = opaque ? PNG.sync.write(PNG.sync.read(png), { colorType: 2 }) : png;
  fs.writeFileSync(path.join(root, relativePath), pixels);
}

render('brand/news.dev/app-icon.png', 512);
render('radar/assets/brand/app-icon.png', 512);
render('radar/assets/brand/mark.png', 192);

const ios = 'radar/ios/Runner/Assets.xcassets/AppIcon.appiconset';
const { images } = JSON.parse(fs.readFileSync(path.join(root, ios, 'Contents.json'), 'utf8'));
for (const { filename, size, scale } of images) {
  if (filename) render(ios + '/' + filename, parseFloat(size) * parseFloat(scale), true);
}

const android = 'radar/android/app/src/main/res';
for (const [density, size] of Object.entries({ mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 })) {
  render(android + '/mipmap-' + density + '/ic_launcher.png', size);
}

render('radar/web/favicon.png', 48);
for (const size of [192, 512]) {
  render('radar/web/icons/Icon-' + size + '.png', size);
  render('radar/web/icons/Icon-maskable-' + size + '.png', size);
}
