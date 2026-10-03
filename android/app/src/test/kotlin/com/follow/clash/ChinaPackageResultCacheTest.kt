package com.follow.clash.plugins

import org.junit.Assert.assertEquals
import org.junit.Test

class ChinaPackageResultCacheTest {
    @Test
    fun `reuses result while package update time is unchanged`() {
        val cache = ChinaPackageResultCache()
        var computeCount = 0

        val first = cache.getOrPut("com.example.app", 10L) {
            computeCount++
            true
        }
        val second = cache.getOrPut("com.example.app", 10L) {
            computeCount++
            false
        }

        assertEquals(true, first)
        assertEquals(true, second)
        assertEquals(1, computeCount)
    }

    @Test
    fun `recomputes result after package update time changes`() {
        val cache = ChinaPackageResultCache()
        var computeCount = 0

        val beforeUpdate = cache.getOrPut("com.example.app", 10L) {
            computeCount++
            false
        }
        val afterUpdate = cache.getOrPut("com.example.app", 11L) {
            computeCount++
            true
        }

        assertEquals(false, beforeUpdate)
        assertEquals(true, afterUpdate)
        assertEquals(2, computeCount)
    }
}
