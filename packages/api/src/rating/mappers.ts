import {
  type Json,
  boolOr,
  date,
  isObject,
  list,
  numOr,
  obj,
  str,
  strOr,
} from '../json';
import type {
  MyRating,
  MyReviewItem,
  MyReviewPage,
  PlayerRatingDetail,
  RatedMatch,
  RatingDistribution,
  RatingPlayerDetail,
  Review,
} from './types';

export function toRatingDistribution(json: Json): RatingDistribution {
  return {
    rating: numOr(json.rating, 0),
    count: numOr(json.count, 0),
    percentage: numOr(json.percentage, 0),
  };
}

export function toRatingPlayerDetail(json: Json): RatingPlayerDetail {
  return {
    participantId: numOr(json.participantId, 0),
    playerId: numOr(json.playerId, 0),
    playerName: strOr(json.playerName, ''),
    playerImageUrl: strOr(json.playerImageUrl, ''),
    teamSide: strOr(json.teamSide, ''),
    role: strOr(json.role, ''),
    championName: strOr(json.championName, ''),
    kills: numOr(json.kills, 0),
    deaths: numOr(json.deaths, 0),
    assists: numOr(json.assists, 0),
  };
}

export function toMyRating(json: Json): MyRating {
  return {
    ratingId: numOr(json.ratingId, 0),
    rating: numOr(json.rating, 0),
    comment: str(json.comment),
  };
}

export function toReview(json: Json): Review {
  return {
    ratingId: numOr(json.ratingId, 0),
    nickname: strOr(json.nickname, ''),
    profileImageUrl: str(json.profileImageUrl),
    teamImageUrl: str(json.teamImageUrl),
    rating: numOr(json.rating, 0),
    comment: str(json.comment),
    // 비로그인이면 서버가 안 보낸다 — 없으면 "내 것이 아니다" 가 안전하다
    // (잘못 true 면 남의 리뷰에 삭제 버튼이 붙는다).
    mine: boolOr(json.mine, false),
    createdAt: date(json.createdAt),
    updatedAt: date(json.updatedAt),
  };
}

export function toPlayerRatingDetail(json: unknown): PlayerRatingDetail {
  if (!isObject(json)) throw new TypeError('PlayerRatingDetail: 객체가 아니다');
  return {
    gameId: strOr(json.gameId, ''),
    // 모르면 작성 불가로 본다 — 버튼을 잘못 띄워 서버가 거절하는 것보다
    // 안 띄우는 쪽이 조용하다.
    rateable: boolOr(json.rateable, false),
    player: toRatingPlayerDetail(isObject(json.player) ? json.player : {}),
    averageRating: numOr(json.averageRating, 0),
    ratingCount: numOr(json.ratingCount, 0),
    distribution: list(json.distribution, toRatingDistribution),
    // 비로그인이면 null 이다. Dart 도 같다.
    myRating: obj(json.myRating, toMyRating),
    reviews: list(json.reviews, toReview),
    page: numOr(json.page, 0),
    size: numOr(json.size, 0),
    totalElements: numOr(json.totalElements, 0),
    totalPages: numOr(json.totalPages, 0),
  };
}

export function toRatedMatch(json: Json): RatedMatch {
  return {
    matchId: strOr(json.matchId, ''),
    gameOrder: numOr(json.gameOrder, 0),
    leagueName: strOr(json.leagueName, ''),
    matchTitle: strOr(json.matchTitle, ''),
    blueTeamCode: strOr(json.blueTeamCode, ''),
    redTeamCode: strOr(json.redTeamCode, ''),
    matchDate: date(json.matchDate),
  };
}

export function toMyReviewItem(json: Json): MyReviewItem {
  return {
    ratingId: numOr(json.ratingId, 0),
    gameId: strOr(json.gameId, ''),
    participantId: numOr(json.participantId, 0),
    playerId: numOr(json.playerId, 0),
    playerName: strOr(json.playerName, ''),
    playerImageUrl: strOr(json.playerImageUrl, ''),
    teamSide: strOr(json.teamSide, ''),
    role: strOr(json.role, ''),
    championName: strOr(json.championName, ''),
    rating: numOr(json.rating, 0),
    comment: str(json.comment),
    createdAt: date(json.createdAt),
    updatedAt: date(json.updatedAt),
    profileImageUrl: str(json.profileImageUrl),
    teamImageUrl: str(json.teamImageUrl),
    // 매핑이 없으면 null — 화면이 리그·팀 줄을 통째로 비운다(Dart 와 같다).
    match: obj(json.match, toRatedMatch),
  };
}

export function toMyReviewPage(json: unknown): MyReviewPage {
  if (!isObject(json)) throw new TypeError('MyReviewPage: 객체가 아니다');
  return {
    ratings: list(json.ratings, toMyReviewItem),
    page: numOr(json.page, 0),
    size: numOr(json.size, 0),
    totalElements: numOr(json.totalElements, 0),
    totalPages: numOr(json.totalPages, 0),
  };
}
