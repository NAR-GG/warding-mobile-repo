package com.warding.app

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 배정된 높이만큼 경기 행을 보여주는 로직.
 *
 * 위젯을 리사이즈로 늘리면 그만큼 더 보여야 한다.
 */
class SlotsForHeightTest {

    @Test
    fun `높이를 못 구하면 기본 개수로 대체한다`() {
        // 옵션 미제공(0)일 때 화면이 비어버리면 안 된다.
        assertTrue(slotsForHeight(0) >= 1)
        assertTrue(slotsForHeight(-1) >= 1)
    }

    @Test
    fun `1칸 높이에서는 최소 1줄은 보여준다`() {
        // 40dp: chrome(46dp)보다도 작아 계산상 0 이하지만 1줄로 올려 준다.
        assertEquals(1, slotsForHeight(40))
    }

    @Test
    fun `높이를 늘리면 줄 수가 늘어난다`() {
        val small = slotsForHeight(80)
        val medium = slotsForHeight(140)
        val large = slotsForHeight(200)

        assertTrue("80dp=$small 140dp=$medium", medium > small)
        assertTrue("140dp=$medium 200dp=$large", large > medium)
    }

    @Test
    fun `아무리 늘려도 상한을 넘지 않는다`() {
        assertEquals(slotsForHeight(1000), slotsForHeight(2000))
        assertTrue(slotsForHeight(2000) <= 6)
    }

    @Test
    fun `슬롯 수만큼만 행을 만든다`() {
        val matches = (1..8).map {
            TodayMatchInfo(time = "1$it:00", status = "unstarted", display = "A$it VS B$it")
        }

        val result = selectDisplayMatches(matches, maxSlots = 3)

        assertEquals(3, result.rows.size)
        assertEquals(5, result.overflowCount)
    }

    @Test
    fun `지난 경기는 한 개만 자리를 차지한다`() {
        val matches = listOf(
            TodayMatchInfo("10:00", "finished", "A VS B"),
            TodayMatchInfo("12:00", "finished", "C VS D"),
            TodayMatchInfo("17:00", "unstarted", "E VS F"),
            TodayMatchInfo("19:00", "unstarted", "G VS H"),
        )

        val result = selectDisplayMatches(matches, maxSlots = 3)

        // 끝난 경기 2개 중 마지막 1개 + 예정 2개
        assertEquals(3, result.rows.size)
        assertEquals(MatchRole.PAST, result.rows[0].role)
        assertEquals("C VS D", result.rows[0].match.display)
        assertEquals(MatchRole.NEXT, result.rows[1].role)
    }

    @Test
    fun `슬롯이 1개면 지난 경기만으로 채우지 않는다`() {
        val matches = listOf(
            TodayMatchInfo("10:00", "finished", "A VS B"),
            TodayMatchInfo("17:00", "unstarted", "E VS F"),
        )

        val result = selectDisplayMatches(matches, maxSlots = 1)

        // 자리가 하나뿐이면 지난 경기가 차지하고 나머지는 오버플로로 간다.
        assertEquals(1, result.rows.size)
        assertEquals(1, result.overflowCount)
    }
}
