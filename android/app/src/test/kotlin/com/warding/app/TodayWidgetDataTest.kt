package com.warding.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar

/**
 * 위젯이 저장된 오늘 경기 데이터를 오늘 것인지 판정하는 로직.
 *
 * 자정을 넘겨도 어제 경기가 오늘인 척 남던 버그의 회귀 방지.
 */
class TodayWidgetDataTest {

    private fun json(date: String, matches: String = "[]") =
        """{"date":"$date","weekday":4,"matches":$matches}"""

    private val oneMatch =
        """[{"matchId":"1","time":"17:00","status":"unstarted","display":"T1 VS GEN"}]"""

    @Test
    fun `오늘 날짜면 경기를 그대로 읽는다`() {
        val data = parseTodayData(json("2026-08-21", oneMatch), "2026-08-21")

        assertFalse(data.isStale)
        assertEquals(1, data.matches.size)
        assertEquals("17:00", data.matches[0].time)
        assertEquals("T1 VS GEN", data.matches[0].display)
    }

    @Test
    fun `어제 날짜면 경기를 버리고 stale 로 표시한다`() {
        val data = parseTodayData(json("2026-08-20", oneMatch), "2026-08-21")

        assertTrue(data.isStale)
        assertTrue(data.matches.isEmpty())
    }

    @Test
    fun `오늘인데 경기가 없으면 stale 이 아니다`() {
        // "경기 없음"과 "아직 모름"은 위젯에서 다르게 보여야 한다.
        val data = parseTodayData(json("2026-08-21"), "2026-08-21")

        assertFalse(data.isStale)
        assertTrue(data.matches.isEmpty())
    }

    @Test
    fun `저장된 값이 없으면 stale 이다`() {
        assertTrue(parseTodayData(null, "2026-08-21").isStale)
    }

    @Test
    fun `date 필드가 없는 옛 저장분은 stale 이다`() {
        val legacy = """{"weekday":4,"matches":$oneMatch}"""

        assertTrue(parseTodayData(legacy, "2026-08-21").isStale)
    }

    @Test
    fun `깨진 JSON 은 stale 이다`() {
        assertTrue(parseTodayData("{not json", "2026-08-21").isStale)
    }

    @Test
    fun `todayKey 는 앱이 저장하는 형식과 같은 0 채움을 쓴다`() {
        val cal = Calendar.getInstance().apply { set(2026, Calendar.JANUARY, 5) }

        assertEquals("2026-01-05", todayKey(cal))
    }
}
