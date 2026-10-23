require "test_helper"

class StatsHelperTest < ActionView::TestCase
  Point = Report::Stats::Point

  def points(*totals)
    start = Date.new(2026, 10, 5)
    totals.each_with_index.map { |total, index| Point.new(week: start + index.weeks, total: total) }
  end

  test "a young site pads its growth chart on the left so columns stay narrow" do
    two = points(6, 103)

    assert_equal 10, growth_blank_columns(two)
    assert_equal Date.new(2026, 7, 27), growth_first_week(two)
    # 12 columns of 20 units, less the 2-unit gap after the last.
    assert_includes growth_columns(two), 'viewBox="0 0 238 158"'
    assert_equal 2 * 0 + (1 + 16), growth_columns(two).scan("<rect").size
  end

  test "a chart with a full year of weeks is not padded" do
    many = points(*(1..26).to_a)

    assert_equal 0, growth_blank_columns(many)
    assert_equal many.first.week, growth_first_week(many)
  end
end
