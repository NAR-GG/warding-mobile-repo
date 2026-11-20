// 웹 전용 순수 함수. `export *` 를 쓰지 않는다 — 무엇이 공개되는지 이 파일만
// 보고 알 수 있어야 하고, 내부 구현이 늘 때 조용히 새지 않는다.

export { formatDate } from './formatDate';
export { timeAgo } from './timeAgo';
export { useDismissKeyboard } from './useDismissKeyboard';

export { cloudinaryScaled } from './cloudinary';

export { resizeImage } from './resizeImage';
export type { ResizeResult } from './resizeImage';

export { uploadToCloudinary } from './uploadImage';
export type { CloudinarySignature } from './uploadImage';

export { DRAFT_MAX_AGE_DAYS, clearDraft, loadDraft, saveDraft } from './postDraft';
export type { PostDraft } from './postDraft';
