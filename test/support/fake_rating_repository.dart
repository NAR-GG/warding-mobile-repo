import 'package:mocktail/mocktail.dart';
import 'package:warding/core/infrastructure/rating/rating_repository.dart';
import 'package:warding/features/match_detail/data/match_detail_repository.dart';

class MockRatingRepository extends Mock implements RatingRepository {}

class MockMatchDetailRepository extends Mock
    implements MatchDetailRepository {}
