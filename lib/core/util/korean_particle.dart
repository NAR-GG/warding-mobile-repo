/// 한국어 조사 '(으)로' 를 받침 유무에 따라 선택한다.
///
/// 마지막 글자에 받침이 있으면 '으로', 없거나 'ㄹ' 받침이면 '로'.
/// 한글이 아닌 문자로 끝나면 기본 '으로'를 붙인다.
String particleEuro(String word) {
  if (word.isEmpty) return '으로';
  final last = word.codeUnitAt(word.length - 1);
  // 한글 유니코드 범위: 0xAC00 ~ 0xD7A3
  if (last < 0xAC00 || last > 0xD7A3) return '으로';
  final jongseong = (last - 0xAC00) % 28;
  // jongseong 0 = 받침 없음, 8 = ㄹ 받침 → '로'
  if (jongseong == 0 || jongseong == 8) return '로';
  return '으로';
}
