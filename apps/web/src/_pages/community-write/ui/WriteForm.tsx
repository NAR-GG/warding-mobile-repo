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

import { createPostAction, signUploadAction } from '../api/actions';

/** 한 글에 붙일 수 있는 사진 수. Dart 와 같은 상한이다. */
const MAX_PHOTOS = 10;

/** 자동 저장 간격. 타이핑마다 쓰면 localStorage 가 과하게 돈다. */
const AUTOSAVE_MS = 2000;

type Photo =
  /** 올리는 중. 미리보기는 로컬 objectURL 이다. */
  | { state: 'uploading'; previewUrl: string }
  /** 올라감. `url` 이 Cloudinary `secure_url` 이고 이것만 드래프트에 남는다. */
  | { state: 'done'; previewUrl: string; url: string }
  | { state: 'failed'; previewUrl: string };

/**
 * 글쓰기 — 제목 · 본문(평문) · 사진.
 *
 * **사진은 고르는 즉시 올린다**(선업로드). 사용자가 제목·본문을 쓰는 동안
 * 업로드가 끝나서 등록 버튼은 `createPost` 한 번으로 끝난다 — Flutter 가
 * 쓰는 패턴 그대로다. 대신 글을 안 쓰고 나가면 Cloudinary 에 고아 파일이
 * 남는데, 앱도 이미 같은 비용을 감수하고 있다.
 *
 * **리사이즈는 브라우저가 한다**(`resizeImage`). `<input type="file">` 에는
 * `image_picker` 같은 옵션이 없어 원본이 그대로 오고, Cloudinary 의 변환은
 * 파일이 도착한 **뒤** 일어나 업로드 대역폭을 줄이지 못한다.
 *
 * 블록 에디터·투표·링크 프리뷰는 다음 단계다.
 */
export function WriteForm() {
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [photos, setPhotos] = useState<Photo[]>([]);
  const [submitting, setSubmitting] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [restored, setRestored] = useState(false);

  const fileInput = useRef<HTMLInputElement>(null);

  // 임시저장 복원은 첫 렌더 뒤 한 번만. localStorage 는 서버에 없다.
  useEffect(() => {
    const draft = loadDraft();
    if (draft === null) return;
    setTitle(draft.title);
    setBody(draft.body);
    setPhotos(
      draft.imageUrls.map((url) => ({ state: 'done', previewUrl: url, url })),
    );
    setRestored(true);
  }, []);

  // 자동 저장. 올라간 사진의 URL 만 담는다 — 올리는 중인 것은 복원해도
  // 이어갈 수 없다.
  useEffect(() => {
    if (title === '' && body === '' && photos.length === 0) return;

    const timer = setTimeout(() => {
      saveDraft({
        title,
        body,
        imageUrls: photos
          .filter((p): p is Extract<Photo, { state: 'done' }> => p.state === 'done')
          .map((p) => p.url),
      });
    }, AUTOSAVE_MS);

    return () => clearTimeout(timer);
  }, [title, body, photos]);

  async function onPick(files: FileList | null) {
    if (files === null || files.length === 0) return;

    const room = MAX_PHOTOS - photos.length;
    if (room <= 0) {
      setNotice(`사진은 ${MAX_PHOTOS}장까지 올릴 수 있어요`);
      return;
    }

    const picked = Array.from(files).slice(0, room);
    setNotice(null);

    // 자리를 먼저 잡아 두고 비동기로 채운다 — 고른 순서가 유지된다.
    const entries = picked.map((file) => ({
      file,
      previewUrl: URL.createObjectURL(file),
    }));
    setPhotos((prev) => [
      ...prev,
      ...entries.map(({ previewUrl }) => ({ state: 'uploading' as const, previewUrl })),
    ]);

    for (const { file, previewUrl } of entries) {
      void upload(file, previewUrl);
    }
  }

  async function upload(file: File, previewUrl: string) {
    // **인덱스가 아니라 `previewUrl` 로 찾는다.** 올리는 사이에 사용자가 앞쪽
    // 사진을 지우면 인덱스가 밀려 엉뚱한 자리를 덮어쓴다.
    const replace = (next: Photo) =>
      setPhotos((prev) =>
        prev.map((p) => (p.previewUrl === previewUrl ? next : p)),
      );

    try {
      const resized = await resizeImage(file);

      const sig = await signUploadAction();
      if (sig.kind === 'unauthorized') {
        setNotice('로그인이 필요합니다');
        replace({ state: 'failed', previewUrl });
        return;
      }
      if (sig.kind === 'failed') {
        replace({ state: 'failed', previewUrl });
        return;
      }

      const url = await uploadToCloudinary(sig.value, resized.blob);
      replace({ state: 'done', previewUrl, url });
    } catch {
      // 리사이즈·업로드 어느 쪽이 터져도 그 장만 실패로 둔다 — 나머지는
      // 계속 올라간다.
      replace({ state: 'failed', previewUrl });
    }
  }

  function removePhoto(previewUrl: string) {
    setPhotos((prev) => prev.filter((p) => p.previewUrl !== previewUrl));
  }

  const uploading = photos.some((p) => p.state === 'uploading');
  const failed = photos.some((p) => p.state === 'failed');
  const ready =
    title.trim() !== '' && body.trim() !== '' && !uploading && !submitting;

  async function onSubmit() {
    if (!ready) return;

    // 실패한 사진이 있으면 멈춘다. 사진이 빠진 채 글만 올라가는 것보다
    // 낫다는 Dart 의 판단과 같다.
    if (failed) {
      setNotice('올리지 못한 사진이 있어요. 지우거나 다시 시도해 주세요');
      return;
    }

    setSubmitting(true);
    setNotice(null);

    const r = await createPostAction({
      title,
      body,
      imageUrls: photos
        .filter((p): p is Extract<Photo, { state: 'done' }> => p.state === 'done')
        .map((p) => p.url),
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

      <textarea
        className="write__body"
        value={body}
        onChange={(e) => setBody(e.target.value)}
        placeholder="내용을 입력하세요"
      />

      {photos.length === 0 ? null : (
        <ul className="write__photos">
          {photos.map((photo) => (
            <li
              key={photo.previewUrl}
              className={
                photo.state === 'failed'
                  ? 'write__photo write__photo--failed'
                  : 'write__photo'
              }
            >
              <img src={photo.previewUrl} alt="" />
              {photo.state === 'uploading' ? (
                <span className="write__photo-state">올리는 중…</span>
              ) : null}
              {photo.state === 'failed' ? (
                <span className="write__photo-state">실패</span>
              ) : null}
              <button
                type="button"
                className="write__photo-remove"
                onClick={() => removePhoto(photo.previewUrl)}
                aria-label="사진 삭제"
              >
                ✕
              </button>
            </li>
          ))}
        </ul>
      )}

      <div className="write__tools">
        <button
          type="button"
          className="write__tool"
          onClick={() => fileInput.current?.click()}
        >
          사진 {photos.length}/{MAX_PHOTOS}
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
