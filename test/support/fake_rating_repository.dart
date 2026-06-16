import 'package:mocktail/mocktail.dart';
import 'package:warding/repository/rating/rating_repository.dart';
import 'package:warding/repository/match/match_detail_repository.dart';

class MockRatingRepository extends Mock implements RatingRepository {}

class MockMatchDetailRepository extends Mock
    implements MatchDetailRepository {}
