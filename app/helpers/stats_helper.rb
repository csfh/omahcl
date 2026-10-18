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

  # Cumulative machines per week, one column of stacked squares per week.
  def growth_columns(points)
    max = points.map(&:total).max.to_f
    cells = points.each_with_index.flat_map do |point, column|
      height = [ (point.total / max * GROWTH_ROWS).ceil, 1 ].max
      Array.new(height) do |row|
        tag.rect(
          x: column * 2 * STEP, y: (GROWTH_ROWS - 1 - row) * STEP, width: 2 * STEP - 2, height: CELL,
          class: row == height - 1 ? "fill-accent" : "fill-teal-mid"
        )
      end
    end

    block_svg(points.size * 2 * STEP - 2, GROWTH_ROWS * STEP - 2, cells, label: nil, class: "block h-40 w-full", aspect: "none")
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
