'use client';

import { useEffect, useRef, useState } from 'react';

import { goBack } from '@/shared/bridge';
import {
  DRAFT_MAX_AGE_DAYS,
  clearDraft,
  loadDraft,
  resizeImage,
  saveDraft,
  uploadToCloudinary,
} from '@/shared/lib';

import {
  ensureTextEdges,
  hasContent,
  imageBlock,
  imageUrlsOf,
  insertMedia,
  textBlock,
  toBodyJson,
  type EditorBlock,
} from '../lib/blocks';
import { createPostAction, signUploadAction } from '../api/actions';
import { BlockEditor } from './BlockEditor';

/** 한 글에 붙일 수 있는 사진 수. Dart 와 같은 상한이다. */
const MAX_PHOTOS = 10;

/** 자동 저장 간격. 타이핑마다 쓰면 localStorage 가 과하게 돈다. */
const AUTOSAVE_MS = 2000;

/**
 * 글쓰기 — 제목 + 블록 본문(텍스트·사진).
 *
 * **사진은 고르는 즉시 올린다**(선업로드). 사용자가 글을 쓰는 동안 업로드가
 * 끝나서 등록은 `createPost` 한 번으로 끝난다 — Flutter 가 쓰는 패턴이다.
 * 대신 글을 안 쓰고 나가면 Cloudinary 에 고아 파일이 남는데, 앱도 이미 같은
 * 비용을 감수하고 있다.
 *
 * **업로드가 끝난 뒤에 블록으로 들어간다.** 올리는 중인 사진을 블록에 미리
 * 넣으면 그 상태가 드래프트에 섞이고, 복원했을 때 이어갈 수 없는 항목이
 * 된다. 진행 중인 것은 따로 줄에 보여 준다.
 *
 * 투표 작성·링크 프리뷰는 아직 없다.
 */
export function WriteForm() {
  const [title, setTitle] = useState('');
  const [blocks, setBlocks] = useState<EditorBlock[]>(() => [textBlock()]);
  const [pendingCount, setPendingCount] = useState(0);
  const [failedCount, setFailedCount] = useState(0);
  const [submitting, setSubmitting] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [restored, setRestored] = useState(false);

  /** 커서가 있는 텍스트 블록과 그 안의 위치 — 사진을 여기에 끼운다. */
  const [focusedId, setFocusedId] = useState<string | null>(null);
  const cursor = useRef(0);
  /** 삽입 직후 포커스를 옮길 블록. */
  const [focusAfterInsert, setFocusAfterInsert] = useState<string | null>(null);

  const fileInput = useRef<HTMLInputElement>(null);

  // 임시저장 복원은 첫 렌더 뒤 한 번만. localStorage 는 서버에 없다.
  useEffect(() => {
    const draft = loadDraft();
    if (draft === null) return;

    setTitle(draft.title);
    // 드래프트의 본문은 블록 JSON 이다. 깨졌으면 빈 본문으로 연다 —
    // 복원 실패로 글쓰기 자체를 막지 않는다.
    setBlocks(parseDraftBody(draft.body));
    setRestored(true);
  }, []);

  // 자동 저장. 본문은 블록 JSON 으로, 이미지는 이미 URL 이다.
  useEffect(() => {
    if (title === '' && !hasContent(blocks)) return;

    const timer = setTimeout(() => {
      saveDraft({
        title,
        body: toBodyJson(blocks),
        imageUrls: imageUrlsOf(blocks),
      });
    }, AUTOSAVE_MS);

    return () => clearTimeout(timer);
  }, [title, blocks]);

  async function onPick(files: FileList | null) {
    if (files === null || files.length === 0) return;

    const room = MAX_PHOTOS - imageUrlsOf(blocks).length - pendingCount;
    if (room <= 0) {
      setNotice(`사진은 ${MAX_PHOTOS}장까지 올릴 수 있어요`);
      return;
    }

    const picked = Array.from(files).slice(0, room);
    setNotice(null);
    setPendingCount((n) => n + picked.length);

    for (const file of picked) {
      void upload(file);
    }
  }

  async function upload(file: File) {
    try {
      const resized = await resizeImage(file);

      const sig = await signUploadAction();
      if (sig.kind !== 'ok') {
        setNotice(
          sig.kind === 'unauthorized'
            ? '로그인이 필요합니다'
            : '사진을 올리지 못했어요',
        );
        setFailedCount((n) => n + 1);
        return;
      }

      const url = await uploadToCloudinary(sig.value, resized.blob);

      // 끝난 것만 블록에 넣는다. 커서 위치는 이 시점 기준이다.
      setBlocks((prev) => {
        const r = insertMedia(prev, [imageBlock(url)], focusedId, cursor.current);
        setFocusAfterInsert(r.focusId);
        return r.blocks;
      });
    } catch {
      // 리사이즈·업로드 어느 쪽이 터져도 그 장만 실패로 둔다.
      setFailedCount((n) => n + 1);
      setNotice('사진을 올리지 못했어요');
    } finally {
      setPendingCount((n) => Math.max(0, n - 1));
    }
  }

  const ready =
    title.trim() !== '' && hasContent(blocks) && pendingCount === 0 && !submitting;

  async function onSubmit() {
    if (!ready) return;

    // 실패한 사진이 있으면 멈춘다 — 사진이 빠진 채 글만 올라가는 것보다
    // 낫다는 Dart 의 판단과 같다.
    if (failedCount > 0) {
      setNotice('올리지 못한 사진이 있어요. 다시 시도해 주세요');
      return;
    }

    setSubmitting(true);
    setNotice(null);

    const r = await createPostAction({
      title,
      body: toBodyJson(blocks),
      bodyFormat: 'BLOCKS',
      imageUrls: imageUrlsOf(blocks),
    });

    setSubmitting(false);

    if (r.kind === 'unauthorized') {
      setNotice('로그인이 필요합니다');
      return;
    }
    if (r.kind === 'failed') {
      setNotice('등록하지 못했어요. 잠시 후 다시 시도해 주세요');
      return;
    }

    clearDraft();
    // 등록이 끝나면 네이티브가 목록으로 되돌린다. 웹 히스토리를 쓰면
    // 네이티브 스택과 어긋난다.
    goBack();
  }

  const photoCount = imageUrlsOf(blocks).length;

  return (
    <div className="write">
      <header className="write__header">
        <button type="button" className="write__cancel" onClick={goBack}>
          취소
        </button>
        <button
          type="button"
          className="write__submit"
          onClick={onSubmit}
          disabled={!ready}
        >
          {submitting ? '등록 중…' : '등록'}
        </button>
      </header>

      {restored ? (
        <p className="write__restored">임시저장한 글을 불러왔어요</p>
      ) : null}

      <input
        className="write__title"
        value={title}
        onChange={(e) => setTitle(e.target.value)}
        placeholder="제목"
        maxLength={100}
      />

      <BlockEditor
        blocks={blocks}
        onChange={setBlocks}
        onFocusBlock={setFocusedId}
        onCursor={(p) => {
          cursor.current = p;
        }}
        focusId={focusAfterInsert}
      />

      {pendingCount > 0 ? (
        <p className="write__uploading">사진 {pendingCount}장 올리는 중…</p>
      ) : null}

      <div className="write__tools">
        <button
          type="button"
          className="write__tool"
          onClick={() => fileInput.current?.click()}
        >
          사진 {photoCount}/{MAX_PHOTOS}
        </button>

        {/* `accept` 에 HEIC 을 넣지 않는다 — iOS 가 자동으로 JPEG 로 바꿔
            넘겨 준다. 넣으면 되레 원본 HEIC 이 와서 디코딩에 걸린다. */}
        <input
          ref={fileInput}
          className="write__file"
          type="file"
          accept="image/jpeg,image/png,image/webp"
          multiple
          onChange={(e) => {
            void onPick(e.target.files);
            // 같은 파일을 다시 고를 수 있게 비운다.
            e.target.value = '';
          }}
        />
      </div>

      {notice === null ? null : <p className="write__notice">{notice}</p>}

      {/* 보존 기간을 알린다. 브라우저가 7일간 방문이 없는 사이트의 저장
          데이터를 지우기 때문이고, 네이티브보다 짧은 것은 감수한 선택이다. */}
      <p className="write__draft-note">
        임시저장은 이 기기에 최대 {DRAFT_MAX_AGE_DAYS}일간 보관돼요
      </p>
    </div>
  );
}

/** 드래프트 본문(블록 JSON) → 편집 블록. 깨졌으면 빈 본문으로 연다. */
function parseDraftBody(body: string): EditorBlock[] {
  try {
    const parsed: unknown = JSON.parse(body);
    if (!Array.isArray(parsed)) return [textBlock()];

    const blocks = parsed.flatMap((raw): EditorBlock[] => {
      if (typeof raw !== 'object' || raw === null) return [];
      const b = raw as { type?: unknown; text?: unknown; style?: unknown; url?: unknown };

      if (b.type === 'image' && typeof b.url === 'string') return [imageBlock(b.url)];
      if (b.type === 'text' && typeof b.text === 'string') {
        return [textBlock(b.text, b.style === 'heading')];
      }
      return [];
    });

    // 저장된 JSON 에는 빈 텍스트 블록이 빠져 있다(`toBodyJson` 이 걷어낸다).
    // 그대로 열면 이미지가 첫 블록일 수 있으므로 불변식을 다시 맞춘다.
    return blocks.length === 0 ? [textBlock()] : ensureTextEdges(blocks);
  } catch {
    return [textBlock()];
  }
}
