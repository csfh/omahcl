module StatsHelper
  BAR_CELLS = 14
  GROWTH_ROWS = 16
  CELL = 8
  STEP = 10

  # One row of 8px squares. SVG geometry only, so the CSP's ban on inline style
  # attributes does not matter. The numbers beside it carry the data, so the
  # drawing is hidden from screen readers.
  def block_cells(count, max, label:)
    filled = max.to_i.zero? ? 0 : [ (count.to_f / max * BAR_CELLS).round, count.positive? ? 1 : 0 ].max
    cells = Array.new(BAR_CELLS) do |index|
      tag.rect(x: index * STEP, y: 0, width: CELL, height: CELL, class: index < filled ? "fill-accent" : "fill-teal-deep")
    end

    block_svg(BAR_CELLS * STEP - (STEP - CELL), CELL, cells, label: label, class: "block h-3 w-full")
  end

  # Columns the growth chart always spans, so a young site draws narrow columns at
  # the right edge instead of two huge slabs.
  GROWTH_MIN_COLUMNS = 12

  def growth_blank_columns(points) = [ GROWTH_MIN_COLUMNS - points.size, 0 ].max

  # The week of the chart's first column, which is before the first machine when padded.
  def growth_first_week(points)
    points.first.week - growth_blank_columns(points).weeks
  end

  # Cumulative machines per week, one column of stacked squares per week, after any
  # empty weeks that pad the chart on the left.
  def growth_columns(points)
    max = points.map(&:total).max.to_f
    blanks = growth_blank_columns(points)
    cells = points.each_with_index.flat_map do |point, index|
      column = index + blanks
      height = [ (point.total / max * GROWTH_ROWS).ceil, 1 ].max
      Array.new(height) do |row|
        tag.rect(
          x: column * 2 * STEP, y: (GROWTH_ROWS - 1 - row) * STEP, width: 2 * STEP - 2, height: CELL,
          class: row == height - 1 ? "fill-accent" : "fill-teal-mid"
        )
      end
    end

    block_svg((points.size + blanks) * 2 * STEP - 2, GROWTH_ROWS * STEP - 2, cells, label: nil, class: "block h-40 w-full", aspect: "none")
  end

  def bar_value(row, mode)
    case mode
    when :percent then number_to_percentage(row.count * 100.0 / row.of, precision: 0)
    when :fraction then "#{number_with_delimiter(row.count)} of #{number_with_delimiter(row.of)}"
    else number_with_delimiter(row.count)
    end
  end

  def week_label(date)
    date.strftime("%-d %b")
  end

  private
    def block_svg(width, height, cells, label:, aspect: "xMinYMid meet", **options)
      tag.svg(
        safe_join([ (tag.title(label) if label), *cells ].compact),
        viewBox: "0 0 #{width} #{height}",
        preserveAspectRatio: aspect,
        "shape-rendering": "crispEdges",
        focusable: "false",
        "aria-hidden": "true",
        **options
      )
    end
end
