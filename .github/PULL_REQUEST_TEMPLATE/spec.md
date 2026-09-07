## Spec: <slug>

- 문서: `intent/<slug>/spec.md`
- Intent: `intent/<slug>/intent.md` (있다면)

## 체크리스트
- [ ] Requirements가 Intent의 Proposed outcome을 커버한다
- [ ] Design / Approach에 애매한 부분이 없다
- [ ] Decisions에 "왜 이렇게 정했는지"가 적혀 있다
- [ ] Out of scope를 명시했다
- [ ] 이 설계가 아키텍처·기능 구조를 바꾼다면, 구현 PR에 `warding-okf/` 갱신도 포함한다
  (해당 없으면 체크만 하고 넘어가도 됨 — intent는 "왜"를, warding-okf는 "지금 어떻게
  동작하는가"를 기록하므로 큰 설계 변경은 후자에도 반영되어야 최신 상태 유지됨)

머지 = Spec 승인. 다음 단계는 Plan 작성 후 구현입니다.
