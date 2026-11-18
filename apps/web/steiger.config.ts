import fsd from '@feature-sliced/steiger-plugin';
import { defineConfig } from 'steiger';

export default defineConfig([
  ...fsd.configs.recommended,
  {
    // `_app`·`_pages` 는 Next 라우터 폴더와의 충돌을 피하려고 공식이 정한
    // 레이어명이다. 기본 린터는 오타로 보므로 끈다.
    files: ['./src/_app/**', './src/_pages/**'],
    rules: { 'fsd/typo-in-layer-name': 'off' },
  },
]);
