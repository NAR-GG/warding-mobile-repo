/// `GET /api/categories/tree` 응답 — 시즌 > 리그 > 스플릿 > 팀 트리.
class CategoryTree {
  const CategoryTree({required this.seasons});

  final List<CategorySeason> seasons;

  factory CategoryTree.fromJson(Map<String, dynamic> json) {
    final list = (json['seasons'] as List<dynamic>?) ?? const [];
    return CategoryTree(
      seasons: list
          .map((e) => CategorySeason.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CategorySeason {
  const CategorySeason({required this.year, required this.leagues});

  final int year;
  final List<CategoryLeague> leagues;

  factory CategorySeason.fromJson(Map<String, dynamic> json) {
    final list = (json['leagues'] as List<dynamic>?) ?? const [];
    return CategorySeason(
      year: (json['year'] ?? 0) as int,
      leagues: list
          .map((e) => CategoryLeague.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CategoryLeague {
  const CategoryLeague({required this.name, required this.splits});

  final String name;
  final List<CategorySplit> splits;

  factory CategoryLeague.fromJson(Map<String, dynamic> json) {
    final list = (json['splits'] as List<dynamic>?) ?? const [];
    return CategoryLeague(
      name: (json['name'] ?? '') as String,
      splits: list
          .map((e) => CategorySplit.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CategorySplit {
  const CategorySplit({
    required this.name,
    required this.leagueId,
    required this.teams,
    required this.patches,
  });

  final String name;
  final int leagueId;
  final List<CategoryTeam> teams;
  final List<String> patches;

  factory CategorySplit.fromJson(Map<String, dynamic> json) {
    final teamList = (json['teams'] as List<dynamic>?) ?? const [];
    final patchList = (json['patches'] as List<dynamic>?) ?? const [];
    return CategorySplit(
      name: (json['name'] ?? '') as String,
      leagueId: (json['leagueId'] ?? 0) as int,
      teams: teamList
          .map((e) => CategoryTeam.fromJson(e as Map<String, dynamic>))
          .toList(),
      patches: patchList.map((e) => e as String).toList(),
    );
  }
}

class CategoryTeam {
  const CategoryTeam({required this.id, required this.name});

  final int id;
  final String name;

  factory CategoryTeam.fromJson(Map<String, dynamic> json) {
    return CategoryTeam(
      id: (json['id'] ?? 0) as int,
      name: (json['name'] ?? '') as String,
    );
  }
}
