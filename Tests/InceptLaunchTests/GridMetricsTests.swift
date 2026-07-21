import Testing
@testable import InceptLaunch

@Test func gridRowsAdaptToScreenHeight() {
    // 1080p point layout: 4 full-size rows, no compression.
    #expect(GridMetrics.rows(forScreenHeight: 1080) == 4)
    // Short laptop screens never drop below 4 rows (tiles shrink slightly
    // instead, as a last resort).
    #expect(GridMetrics.rows(forScreenHeight: 900) == 4)
    // Taller 4K/5K point layouts gain rows instead of stretching icons.
    #expect(GridMetrics.rows(forScreenHeight: 1440) == 6)
    #expect(GridMetrics.rows(forScreenHeight: 2160) == 10)
}

@Test func pageCapacityFollowsRowCount() {
    #expect(GridMetrics.pageCapacity(rows: 4) == 28)
    #expect(GridMetrics.pageCapacity(rows: 6) == 42)
}
