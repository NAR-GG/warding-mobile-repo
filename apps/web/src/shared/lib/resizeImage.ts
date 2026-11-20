/**
 * 업로드 전 이미지 축소.
 *
 * Flutter `image_picker` 의 `maxWidth: 1600, imageQuality: 85` 를 웹에서
 * 재현한다 — `<input type="file">` 에는 그런 옵션이 없어 원본이 그대로 온다.
 * 아이폰 사진은 장당 3~5MB 라, 안 줄이면 LTE 업링크로 그걸 그대로 올리게
 * 된다(Dart 주석이 적어 둔 이유와 같다).
 *
 * **Cloudinary 의 incoming transformation 으로는 대체할 수 없다.** 그 변환은
 * 파일이 Cloudinary 에 **도착한 뒤** 일어나므로 업로드 대역폭이 줄지 않는다
 * (공식 문서 확인). 줄어드는 것은 저장 용량과 이후 전송뿐이다.
 *
 * 라이브러리를 쓰지 않는다 — 다운로드 1위(browser-image-compression)가 3년
 * 반째 릴리스가 없고, 소스를 보면 **iOS·Safari 에서는 `createImageBitmap` 을
 * 의도적으로 건너뛰어** 어차피 구식 폴백 경로를 탄다. 우리 타깃이 iOS
 * WKWebView 라 이득이 없다.
 */

/** 긴 변 기준 최대 픽셀. Dart `maxWidth: 1600` 과 같은 값이다. */
const MAX_EDGE = 1600;

/** JPEG 품질. Dart `imageQuality: 85` 와 같은 값이다. */
const QUALITY = 0.85;

/**
 * iOS canvas 면적 한도.
 *
 * MDN: *"notably iOS devices limit the canvas size to only 4,096 x 4,096
 * pixels"*, 그리고 *"Exceeding the maximum dimensions or area renders the
 * canvas unusable."* — **넘으면 예외가 아니라 빈(검은) 이미지가 조용히**
 * 나온다. 그래서 그리기 전에 반드시 줄인다.
 *
 * iOS 18 에서 8192² 로 올랐다는 실측 보고가 있지만 Apple 공식 릴리스 노트에
 * 근거가 없고 구버전 기기가 남아 있어, 보수적으로 4096² 를 쓴다.
 */
const MAX_CANVAS_AREA = 4096 * 4096;

export type ResizeResult = {
  blob: Blob;
  width: number;
  height: number;
};

/**
 * 이미지를 긴 변 [MAX_EDGE] 이하로 줄여 JPEG Blob 으로 돌려준다.
 *
 * 원본이 이미 작아도 JPEG 로 다시 인코딩한다 — 포맷을 하나로 모아야 서버와
 * 화면이 분기하지 않는다(HEIC 가 그대로 올라오는 경우를 흡수하는 효과도 있다).
 *
 * 실패하면 던진다. 호출부가 "이 사진은 못 올린다" 를 사용자에게 알려야 한다 —
 * 조용히 원본을 올리면 업로드가 느려진 이유를 아무도 모른다.
 */
export async function resizeImage(file: File): Promise<ResizeResult> {
  const bitmap = await loadBitmap(file);

  try {
    const { width, height } = fitWithin(bitmap.width, bitmap.height);

    const canvas = document.createElement('canvas');
    canvas.width = width;
    canvas.height = height;

    const ctx = canvas.getContext('2d');
    if (ctx === null) throw new Error('canvas 2d 컨텍스트를 못 얻었다');

    // EXIF 회전을 **직접 처리하지 않는다.** CSS `image-orientation` 의 초깃값이
    // `from-image` 고 WebKit 버그 209849 가 2020 년에 고쳐져, 브라우저가
    // 그릴 때 이미 방향을 적용한다. 여기서 또 돌리면 이중 회전이 된다.
    ctx.drawImage(bitmap, 0, 0, width, height);

    const blob = await toJpegBlob(canvas);
    return { blob, width, height };
  } finally {
    // 비트맵은 GC 를 기다리지 않고 바로 놓는다 — 여러 장을 연속으로 처리하면
    // 메모리가 금방 쌓인다.
    bitmap.close();
  }
}

/**
 * 파일 → `ImageBitmap`.
 *
 * `createImageBitmap` 을 먼저 쓰고, 없거나 실패하면 `<img>` 로 떨어진다.
 * iOS 에서 이 API 가 HEIC 등 일부 포맷을 못 읽는 사례가 보고되어 있어
 * 폴백을 남겨 둔다.
 */
async function loadBitmap(file: File): Promise<ImageBitmap> {
  if (typeof createImageBitmap === 'function') {
    try {
      return await createImageBitmap(file);
    } catch {
      // 폴백으로 넘어간다.
    }
  }

  const url = URL.createObjectURL(file);
  try {
    const img = await loadImageElement(url);
    return await createImageBitmap(img);
  } finally {
    URL.revokeObjectURL(url);
  }
}

function loadImageElement(url: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error('이미지를 읽지 못했다'));
    img.src = url;
  });
}

/**
 * 목표 크기를 정한다 — 긴 변 [MAX_EDGE] 이하, 그리고 **면적이
 * [MAX_CANVAS_AREA] 를 넘지 않게.**
 *
 * 두 조건을 다 보는 이유: 1600 으로 줄이면 면적은 보통 따라 내려가지만,
 * 파노라마처럼 한 변이 극단적으로 긴 사진은 긴 변만 맞춰도 면적이 남는다.
 */
function fitWithin(srcW: number, srcH: number): { width: number; height: number } {
  let scale = Math.min(1, MAX_EDGE / Math.max(srcW, srcH));

  const area = srcW * scale * (srcH * scale);
  if (area > MAX_CANVAS_AREA) {
    scale *= Math.sqrt(MAX_CANVAS_AREA / area);
  }

  // 0 이 되면 canvas 가 못 쓰게 된다. 최소 1px 를 보장한다.
  return {
    width: Math.max(1, Math.round(srcW * scale)),
    height: Math.max(1, Math.round(srcH * scale)),
  };
}

function toJpegBlob(canvas: HTMLCanvasElement): Promise<Blob> {
  return new Promise((resolve, reject) => {
    canvas.toBlob(
      (blob) => {
        // 한도를 넘겨 canvas 가 망가지면 null 이 온다.
        if (blob === null) reject(new Error('이미지를 변환하지 못했다'));
        else resolve(blob);
      },
      'image/jpeg',
      QUALITY,
    );
  });
}
