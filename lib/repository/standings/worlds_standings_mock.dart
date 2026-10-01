import '../../model/worlds_standings.dart';

/// 월즈 순위표 목업(`HOME_MOCKS=true`일 때만 쓰인다).
///
/// warding-docs `features/home/mockup.html`의 2025 롤드컵 예시 데이터(`DATA.swiss`,
/// `DATA.knockout`)를 그대로 옮겼다. 백엔드가 월즈를 지원하면 이 값은 치운다.
const WorldsStandings worldsStandingsMock = WorldsStandings(
  bracket: [
    WorldsBracketRow(record: '3-0', teamCodes: ['AL', 'KT'], advanced: true),
    WorldsBracketRow(
      record: '3-1',
      teamCodes: ['G2', 'GEN', 'HLE'],
      advanced: true,
    ),
    WorldsBracketRow(
      record: '3-2',
      teamCodes: ['CFO', 'T1', 'TES'],
      advanced: true,
    ),
    WorldsBracketRow(
      record: '2-3',
      teamCodes: ['BLG', 'FLY', 'MKOI'],
      advanced: false,
    ),
    WorldsBracketRow(
      record: '1-3',
      teamCodes: ['100T', 'TSW', 'VKS'],
      advanced: false,
    ),
    WorldsBracketRow(record: '0-3', teamCodes: ['FNC', 'PSG'], advanced: false),
  ],
  knockout: [
    WorldsKnockoutRound(
      name: '8강',
      matches: [
        WorldsMatch(
          teamA: WorldsMatchTeam(
            teamCode: 'AL',
            teamName: "Anyone's Legend",
            gameWins: 2,
            won: false,
          ),
          teamB: WorldsMatchTeam(
            teamCode: 'T1',
            teamName: 'T1',
            gameWins: 3,
            won: true,
          ),
        ),
        WorldsMatch(
          teamA: WorldsMatchTeam(
            teamCode: 'G2',
            teamName: 'G2 Esports',
            gameWins: 1,
            won: false,
          ),
          teamB: WorldsMatchTeam(
            teamCode: 'TES',
            teamName: 'Top Esports',
            gameWins: 3,
            won: true,
          ),
        ),
        WorldsMatch(
          teamA: WorldsMatchTeam(
            teamCode: 'HLE',
            teamName: 'Hanwha Life Esports',
            gameWins: 1,
            won: false,
          ),
          teamB: WorldsMatchTeam(
            teamCode: 'GEN',
            teamName: 'Gen.G Esports',
            gameWins: 3,
            won: true,
          ),
        ),
        WorldsMatch(
          teamA: WorldsMatchTeam(
            teamCode: 'CFO',
            teamName: 'CTBC Flying Oyster',
            gameWins: 0,
            won: false,
          ),
          teamB: WorldsMatchTeam(
            teamCode: 'KT',
            teamName: 'kt Rolster',
            gameWins: 3,
            won: true,
          ),
        ),
      ],
    ),
    WorldsKnockoutRound(
      name: '4강',
      matches: [
        WorldsMatch(
          teamA: WorldsMatchTeam(
            teamCode: 'TES',
            teamName: 'Top Esports',
            gameWins: 0,
            won: false,
          ),
          teamB: WorldsMatchTeam(
            teamCode: 'T1',
            teamName: 'T1',
            gameWins: 3,
            won: true,
          ),
        ),
        // 아직 안 끝난 경기 — "오늘" 상태로 시각만 보여주고 세트 스코어는 비운다.
        WorldsMatch(
          teamA: WorldsMatchTeam(teamCode: 'KT', teamName: 'kt Rolster'),
          teamB: WorldsMatchTeam(teamCode: 'GEN', teamName: 'Gen.G Esports'),
          status: WorldsMatchStatus.today,
          todayTime: '오늘 16:00',
        ),
      ],
    ),
    WorldsKnockoutRound(
      name: '결승',
      matches: [
        // 4강이 안 끝나 양쪽 다 미정(TBD) — 결승 카드만 그라디언트로 미리 강조.
        WorldsMatch(
          teamA: WorldsMatchTeam(),
          teamB: WorldsMatchTeam(),
          status: WorldsMatchStatus.upcoming,
          isFinal: true,
        ),
      ],
    ),
  ],
);
