// 브리지 공개 API. 규약(`protocol.ts`)은 Dart 쪽과 짝을 이룬다.

export {
  CHANNEL,
  EVENT_PREFIX,
} from './protocol';
export type {
  BroadcastMessage,
  CallRequest,
  CallResponse,
  NativeEnv,
  NotifyMessage,
  OutgoingMessage,
} from './protocol';

export {
  call,
  goBack,
  installBridgeReceiver,
  isInWebView,
  notifyHeight,
  notifyReady,
  onBroadcast,
  openPhotoViewer,
  pushWebDepth,
  requestNavigate,
  share,
} from './client';
