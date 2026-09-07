import { test } from 'node:test';
import assert from 'node:assert/strict';
import { slugify } from './slugify.js';

test('lowercases and hyphenates', () => {
  assert.equal(slugify('Match Detail TOC Drag'), 'match-detail-toc-drag');
});

test('strips leading/trailing separators', () => {
  assert.equal(slugify('  --Hello World!--  '), 'hello-world');
});

test('collapses repeated separators', () => {
  assert.equal(slugify('a___b   c'), 'a-b-c');
});

test('returns empty string for non-ASCII (e.g. Korean) input — known limitation, guarded at call site', () => {
  assert.equal(slugify('경기 상세'), '');
});
