#!/usr/bin/env node
// 토큰 소스(JSON) → Dart·CSS 생성기.
//
// 기성 변환 엔진을 쓰지 않는다. Flutter 지원이 신뢰할 수준이 아니라서
// `LinearGradient`·`Alignment` 변환이 지저분해진다(→ spec "토큰 파이프라인").
// 입력 형태가 단순해서(색·그라데이션·치수) 직접 쓰는 편이 짧다.
//
// 치수는 375 기준 원시값으로 둔다. `scale` 곱셈은 소비 지점에서 한다 —
// 토큰에 녹이면 플랫폼마다 다른 값이 필요해져 단일 출처가 깨진다.

import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = dirname(fileURLToPath(import.meta.url));
const read = (f) => JSON.parse(readFileSync(join(root, 'source', f), 'utf8'));

const common = read('common.json');
const theme = read('theme.json');

// ── 공통 ────────────────────────────────────────────────

/** `{color.narDark800}` → `narDark800`. 별칭이 아니면 null. */
const aliasOf = (v) =>
  typeof v === 'string' && v.startsWith('{') ? v.slice(1, -1).split('.').pop() : null;

/** `#RRGGBB` 또는 `#RRGGBBAA` → `{ rgb, alpha }` (alpha 0~255). */
function parseHex(hex) {
  const h = hex.replace('#', '');
  return h.length === 8
    ? { rgb: h.slice(0, 6), alpha: parseInt(h.slice(6), 16) }
    : { rgb: h, alpha: 255 };
}

// ── Dart ────────────────────────────────────────────────

const DART_ALIGNMENT = {
  0: ['Alignment.bottomCenter', 'Alignment.topCenter'],
  90: ['Alignment.centerLeft', 'Alignment.centerRight'],
  135: ['Alignment.topLeft', 'Alignment.bottomRight'],
  180: ['Alignment.topCenter', 'Alignment.bottomCenter'],
  270: ['Alignment.centerRight', 'Alignment.centerLeft'],
  315: ['Alignment.bottomRight', 'Alignment.topLeft'],
};

/** 여러 줄 설명은 dartdoc(`///`)으로, 한 줄짜리 짧은 것은 끝 주석으로 낸다. */
function dartDoc(description) {
  if (!description) return { lead: '', trail: '' };
  const lines = description.split('\n');
  // 토큰 원래 이름(`nar_text_4` 같은 것)만 있으면 끝 주석이 읽기 좋다.
  if (lines.length === 1 && /^[a-z0-9_/ —-]+$/.test(description)) {
    return { lead: '', trail: ` // ${description}` };
  }
  return { lead: lines.map((l) => `  /// ${l}`).join('\n') + '\n', trail: '' };
}

function dartColor(name, token) {
  const alias = aliasOf(token.$value);
  const { lead, trail } = dartDoc(token.$description);
  if (alias) return `${lead}  static const Color ${name} = ${alias};${trail}`;
  const { rgb, alpha } = parseHex(token.$value);
  const argb = alpha.toString(16).padStart(2, '0').toUpperCase() + rgb;
  return `${lead}  static const Color ${name} = Color(0x${argb});${trail}`;
}

function dartGradient(name, token) {
  const { lead } = dartDoc(token.$description);
  const { angle, colors, stops } = token.$value;
  const [begin, end] = DART_ALIGNMENT[angle];
  const cols = colors
    .map((c) => {
      const { rgb, alpha } = parseHex(c);
      return `Color(0x${alpha.toString(16).padStart(2, '0').toUpperCase()}${rgb})`;
    })
    .join(', ');
  const stopLine = stops ? `\n    stops: [${stops.join(', ')}],` : '';
  return `${lead}  static const LinearGradient ${name} = LinearGradient(
    begin: ${begin},
    end: ${end},
    colors: [${cols}],${stopLine}
  );`;
}

function buildDart() {
  const lines = [
    '// GENERATED — design_tokens/build.mjs 가 만든다. 직접 고치지 않는다.',
    '// 값을 바꾸려면 design_tokens/source/*.json 을 고치고 `pnpm tokens:build`.',
    '',
    "import 'package:flutter/material.dart';",
    '',
    'class AppColors {',
    '  AppColors._();',
    '',
  ];
  for (const [name, token] of Object.entries(theme.color)) {
    lines.push(dartColor(name, token));
  }
  lines.push('');
  for (const [name, token] of Object.entries(theme.gradient)) {
    lines.push(dartGradient(name, token));
    lines.push('');
  }
  lines.push('}', '');
  return lines.join('\n');
}

// ── CSS ─────────────────────────────────────────────────

/** 토큰 트리를 `--path-to-leaf: value` 로 편다. */
function flatten(node, path = [], out = []) {
  for (const [key, value] of Object.entries(node)) {
    if (key.startsWith('$')) continue;
    if (value && typeof value === 'object' && '$value' in value) {
      out.push([[...path, key], value]);
    } else if (value && typeof value === 'object') {
      flatten(value, [...path, key], out);
    }
  }
  return out;
}

const kebab = (s) => s.replace(/([a-z0-9])([A-Z])/g, '$1-$2').toLowerCase();

function cssValue(token) {
  const alias = aliasOf(token.$value);
  if (alias) return `var(--color-${kebab(alias)})`;
  switch (token.$type) {
    case 'color': {
      const { rgb, alpha } = parseHex(token.$value);
      if (alpha === 255) return `#${rgb.toLowerCase()}`;
      const [r, g, b] = [0, 2, 4].map((i) => parseInt(rgb.slice(i, i + 2), 16));
      return `rgba(${r}, ${g}, ${b}, ${+(alpha / 255).toFixed(3)})`;
    }
    case 'gradient': {
      const { angle, colors, stops } = token.$value;
      const parts = colors.map((c, i) => {
        const { rgb, alpha } = parseHex(c);
        const [r, g, b] = [0, 2, 4].map((j) => parseInt(rgb.slice(j, j + 2), 16));
        const col = alpha === 255 ? `#${rgb.toLowerCase()}` : `rgba(${r}, ${g}, ${b}, ${+(alpha / 255).toFixed(3)})`;
        return stops ? `${col} ${+(stops[i] * 100).toFixed(2)}%` : col;
      });
      return `linear-gradient(${angle}deg, ${parts.join(', ')})`;
    }
    case 'duration':
      return `${token.$value}ms`;
    case 'dimension':
      // 375 기준 원시값. 소비 지점에서 calc(<토큰> * var(--scale)) 로 쓴다.
      return `${token.$value}`;
    default:
      return String(token.$value);
  }
}

function buildCss() {
  const rows = [
    ...flatten({ color: theme.color, gradient: theme.gradient }),
    ...flatten(common),
  ];
  const lines = [
    '/* GENERATED — design_tokens/build.mjs 가 만든다. 직접 고치지 않는다. */',
    '/* 값을 바꾸려면 design_tokens/source/*.json 을 고치고 `pnpm tokens:build`. */',
    '',
    ':root {',
    '  /* Flutter 의 `수치 * scale` 과 같은 결과를 내는 배율 */',
    '  --scale: calc(clamp(320px, 100vw, 430px) / 375);',
    '',
  ];
  for (const [path, token] of rows) {
    const name = path.map(kebab).join('-');
    const desc = token.$description ? ` /* ${token.$description} */` : '';
    lines.push(`  --${name}: ${cssValue(token)};${desc}`);
  }
  lines.push('}', '');
  return lines.join('\n');
}

// ── 실행 ────────────────────────────────────────────────

mkdirSync(join(root, 'build'), { recursive: true });
writeFileSync(join(root, 'build', 'tokens.css'), buildCss());
writeFileSync(join(root, '..', 'lib', 'core', 'theme', 'app_colors.dart'), buildDart());

const n = Object.keys(theme.color).length + Object.keys(theme.gradient).length;
console.log(`생성 완료 — 색·그라데이션 ${n}개`);
console.log('  lib/core/theme/app_colors.dart');
console.log('  design_tokens/build/tokens.css');
