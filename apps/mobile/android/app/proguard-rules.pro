# okhttp(http 패키지 의존)이 참조하는 선택적 TLS 백엔드 클래스들.
# 런타임에 존재하지 않아도 동작하므로 R8 누락 클래스 경고를 억제한다.
-dontwarn org.conscrypt.Conscrypt$Version
-dontwarn org.conscrypt.Conscrypt
-dontwarn org.conscrypt.ConscryptHostnameVerifier
-dontwarn org.openjsse.javax.net.ssl.SSLParameters
-dontwarn org.openjsse.javax.net.ssl.SSLSocket
-dontwarn org.openjsse.net.ssl.OpenJSSE
