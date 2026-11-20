import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Resvg } from '@resvg/resvg-js';
import opentype from 'opentype.js';
import { PNG } from 'pngjs';

const project = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const app = path.join(project, 'radar');
const assets = path.join(app, 'assets/brand');
const exports = path.join(project, 'brand/fionova');
fs.mkdirSync(assets, { recursive: true });
fs.mkdirSync(exports, { recursive: true });

const colors = { background: '#10141E', lime: '#D4FF3A', cyan: '#57DEED', white: '#F5F7FA', muted: '#9BA5B7' };
const fPath = 'M270 248H716V310L666 360H410V466H650V528L600 578H410V776H270Z M306 668Q306 660 314 660Q322 660 322 668V696H338.144A16 16 0 1 1 338.144 712H314Q306 712 306 704Z';
const pagePath = 'M574 600H732L790 658V758Q790 782 766 782H574Q550 782 550 758V624Q550 600 574 600Z';
const foldPath = 'M732 600V658H790';
const svg = (body, width = 1024, height = 1024) => `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">${body}</svg>`;

function symbol({ mono = null } = {}) {
  return `<g transform="translate(-20 0)">
    <path fill="${mono || colors.lime}" fill-rule="evenodd" d="${fPath}"/>
    <path d="${pagePath}" fill="${mono ? 'none' : colors.background}" stroke="${mono || colors.cyan}" stroke-width="20" stroke-linejoin="round"/>
    <path d="${foldPath}" fill="none" stroke="${mono || colors.cyan}" stroke-width="20" stroke-linejoin="round"/>
    <rect x="582" y="638" width="56" height="56" rx="6" fill="${mono || colors.cyan}"/>
    <path d="M666 682H748M666 709H748M582 744H748" stroke="${mono || colors.cyan}" stroke-width="14" stroke-linecap="round"/>
  </g>`;
}

const appIcon = svg(`<rect width="1024" height="1024" fill="${colors.background}"/>${symbol()}`);
const roundedIcon = svg(`<rect width="1024" height="1024" rx="228" fill="${colors.background}"/>${symbol()}`);
const mark = svg(symbol());

function saveSvg(name, value) { fs.writeFileSync(path.join(exports, name), value + '\n'); }
function png(value, size, output, opaque = false) {
  const rendered = new Resvg(value, { fitTo: { mode: 'width', value: size } }).render().asPng();
  fs.mkdirSync(path.dirname(output), { recursive: true });
  fs.writeFileSync(output, opaque ? PNG.sync.write(PNG.sync.read(rendered), { colorType: 2 }) : rendered);
}
saveSvg('fionova-symbol.svg', mark);
saveSvg('fionova-app-icon.svg', appIcon);
saveSvg('fionova-rounded-icon.svg', roundedIcon);
saveSvg('fionova-symbol-white.svg', svg(symbol({ mono: '#FFFFFF' })));
saveSvg('fionova-symbol-dark.svg', svg(symbol({ mono: '#10141E' })));
png(appIcon, 1024, path.join(assets, 'app-icon.png'));
png(mark, 1024, path.join(assets, 'mark.png'));
png(roundedIcon, 1024, path.join(exports, 'fionova-icon-preview.png'));
png(mark, 1024, path.join(exports, 'fionova-symbol.png'));

// Fontes locais são convertidas em contornos; nenhum arquivo de fonte é distribuído.
const fontFile = process.env.BRAND_FONT || 'C:/Windows/Fonts/segoeuib.ttf';
const font = opentype.loadSync(fontFile);
function text(value, x, baseline, size, fill = colors.white) {
  return `<path d="${font.getPath(value, x, baseline, size, { kerning: true }).toPathData(3)}" fill="${fill}"/>`;
}
function wordmark(fill) {
  return svg(`<g transform="translate(12 12) scale(.27)"><rect width="1024" height="1024" rx="228" fill="${colors.background}"/>${symbol()}</g>${text('Fionova', 340, 218, 184, fill)}`, 1400, 300);
}
saveSvg('fionova-logo-horizontal.svg', wordmark(colors.white));
saveSvg('fionova-logo-on-light.svg', wordmark(colors.background));
png(wordmark(colors.white), 1400, path.join(exports, 'fionova-logo-horizontal.png'));

// Android legados, com fundo opaco: o sistema aplica sua própria máscara quando possível.
for (const [density, size] of Object.entries({ mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 })) {
  png(roundedIcon, size, path.join(app, `android/app/src/main/res/mipmap-${density}/ic_launcher.png`));
}

// Ícones iOS sem transparência e sem cantos pré-arredondados.
const iconSet = path.join(app, 'ios/Runner/Assets.xcassets/AppIcon.appiconset');
const catalogue = JSON.parse(fs.readFileSync(path.join(iconSet, 'Contents.json'), 'utf8'));
for (const icon of catalogue.images) {
  if (icon.filename) png(appIcon, Math.round(parseFloat(icon.size) * parseFloat(icon.scale)), path.join(iconSet, icon.filename), true);
}
const launch = path.join(app, 'ios/Runner/Assets.xcassets/LaunchImage.imageset');
for (const [name, size] of [['LaunchImage.png', 128], ['LaunchImage@2x.png', 256], ['LaunchImage@3x.png', 384]]) {
  png(mark, size, path.join(launch, name));
}
for (const size of [192, 512]) {
  png(roundedIcon, size, path.join(app, `web/icons/Icon-${size}.png`));
  png(appIcon, size, path.join(app, `web/icons/Icon-maskable-${size}.png`));
}
png(roundedIcon, 48, path.join(app, 'web/favicon.png'));

// Android adaptativo: margens seguras para máscaras circulares e ícones temáticos.
function vector(mono = false) {
  const lime = mono ? '#FFFFFFFF' : '#FFD4FF3A';
  const cyan = mono ? '#FFFFFFFF' : '#FF57DEED';
  return `<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="1024" android:viewportHeight="1024">
  <group android:pivotX="512" android:pivotY="512" android:scaleX="0.8" android:scaleY="0.8" android:translateX="-16">
    <path android:fillColor="${lime}" android:fillType="evenOdd" android:pathData="${fPath}"/>
    <path android:fillColor="${mono ? '#00000000' : '#FF10141E'}" android:strokeColor="${cyan}" android:strokeWidth="20" android:strokeLineJoin="round" android:pathData="${pagePath}"/>
    <path android:fillColor="#00000000" android:strokeColor="${cyan}" android:strokeWidth="20" android:strokeLineJoin="round" android:pathData="${foldPath}"/>
    <path android:fillColor="${cyan}" android:pathData="M588 638H632Q638 638 638 644V688Q638 694 632 694H588Q582 694 582 688V644Q582 638 588 638Z"/>
    <path android:fillColor="#00000000" android:strokeColor="${cyan}" android:strokeWidth="14" android:strokeLineCap="round" android:pathData="M666 682H748M666 709H748M582 744H748"/>
  </group>
</vector>\n`;
}
const res = path.join(app, 'android/app/src/main/res');
fs.writeFileSync(path.join(res, 'drawable/fionova_launcher_foreground.xml'), vector());
fs.writeFileSync(path.join(res, 'drawable/fionova_launcher_monochrome.xml'), vector(true));
for (const level of [26, 33]) {
  const dir = path.join(res, `mipmap-anydpi-v${level}`); fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, 'ic_launcher.xml'), `<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@color/fionova_icon_background"/>
  <foreground android:drawable="@drawable/fionova_launcher_foreground"/>
  ${level >= 33 ? '<monochrome android:drawable="@drawable/fionova_launcher_monochrome"/>' : ''}
</adaptive-icon>\n`);
}
fs.writeFileSync(path.join(res, 'values/brand_colors.xml'), `<?xml version="1.0" encoding="utf-8"?>
<resources><color name="fionova_icon_background">${colors.background}</color></resources>\n`);

const board = svg(`
  <rect width="1600" height="1000" fill="#080D15"/>
  <rect x="32" y="32" width="1536" height="936" rx="32" fill="#0D131E" stroke="#202B3C"/>
  ${text('FIONOVA / IDENTIDADE DO APLICATIVO', 88, 100, 20, colors.muted)}
  <g transform="translate(72 145) scale(.7)">${text('Fionova', 0, 190, 184)}</g>
  ${text('Fio de informação. Novas ideias.', 88, 358, 31, colors.muted)}
  ${text('TECNOLOGIA + NOTÍCIAS', 88, 415, 19, colors.lime)}
  <g transform="translate(1100 112) scale(.34)"><rect width="1024" height="1024" rx="228" fill="${colors.background}" stroke="#263349" stroke-width="3"/>${symbol()}</g>
  <path d="M88 490H1512" stroke="#263043"/>
  ${text('UM SÍMBOLO, TRÊS LEITURAS', 88, 554, 19, colors.muted)}
  ${text('F', 94, 655, 75, colors.lime)}
  ${text('Fionova', 88, 712, 25)}
  ${text('Monograma com cortes digitais', 88, 749, 18, colors.muted)}
  <g transform="translate(500 510) scale(.18)">${symbol()}</g>
  ${text('Conexão', 510, 712, 25)}
  ${text('Detalhe inspirado em circuito', 510, 749, 18, colors.muted)}
  <g transform="translate(900 360) scale(.4)"><path d="${pagePath}" fill="none" stroke="${colors.cyan}" stroke-width="20" stroke-linejoin="round"/><path d="${foldPath}" fill="none" stroke="${colors.cyan}" stroke-width="20"/><rect x="582" y="638" width="56" height="56" rx="6" fill="${colors.cyan}"/><path d="M666 682H748M666 709H748M582 744H748" stroke="${colors.cyan}" stroke-width="14" stroke-linecap="round"/></g>
  ${text('Notícia', 1110, 712, 25)}
  ${text('Pequeno jornal, sem excesso visual', 1110, 749, 17, colors.muted)}
  <path d="M88 851H1512" stroke="#263043"/>
  ${[[88, colors.background, 'GRAFITE'], [460, colors.lime, 'VERDE-LIMA'], [832, colors.cyan, 'CIANO'], [1204, colors.white, 'GELO']].map(([x, fill, label]) => `<rect x="${x}" y="889" width="42" height="30" rx="8" fill="${fill}" stroke="#344156"/>${text(label, x + 56, 911, 16, colors.muted)}`).join('')}
`, 1600, 1000);
saveSvg('fionova-brand-preview.svg', board);
png(board, 1600, path.join(exports, 'fionova-brand-preview.png'));
fs.writeFileSync(path.join(exports, 'palette.json'), JSON.stringify(colors, null, 2) + '\n');
console.log('Fionova: SVGs, PNGs e ícones Android/iOS/web gerados.');
