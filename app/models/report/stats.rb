# What the home and model pages chart. Every figure is limited to
# Report.visible, so candidates and hidden machines never show, and counts
# distinct machines (instance_digest). It deliberately never reads
# submitted_ip_digest except to apply the Verified rule. Pass a scope, such as
# one model's reports, to narrow every figure.
class Report::Stats
  GIB = 1024**3

  Row = Data.define(:label, :count, :of) do
    def initialize(label:, count:, of: nil) = super
  end
  Point = Data.define(:week, :total)

  # The collector sends the raw DMI chassis_type number, so name it. Numbers are
  # the SMBIOS System Enclosure types (section 7.4.1; names as in dmidecode).
  # Bit 7 is the chassis lock flag, so it is masked off. Anything else is "Other".
  CHASSIS_GROUPS = {
    "Laptop" => [ 8, 9, 10, 14 ],
    "Desktop" => [ 3, 4, 5, 6, 7, 15, 16 ],
    "All-in-one" => [ 13 ],
    "Mini PC" => [ 34, 35, 36 ],
    "Tablet or 2-in-1" => [ 11, 30, 31, 32 ],
    "Server" => [ 17, 18, 19, 20, 21, 22, 23, 25, 26, 27, 28, 29 ]
  }.flat_map { |label, types| types.map { |type| [ type, label ] } }.to_h.freeze

  MEMORY_EDGES = [ 4, 8, 16, 32, 64 ].map { |gib| gib * GIB }.freeze
  MEMORY_LABELS = [ "4 GB or less", "8 GB", "16 GB", "32 GB", "64 GB", "More than 64 GB" ].freeze
  CORE_EDGES = [ 2, 4, 8, 16 ].freeze
  CORE_LABELS = [ "1–2", "3–4", "5–8", "9–16", "17 or more" ].freeze

  def initialize(scope = Report.all)
    @scope = scope.merge(Report.visible)
  end

  def machines
    @machines ||= scope.distinct.count(:instance_digest)
  end

  def models
    @models ||= scope.distinct.count(:model_key)
  end

  def verified_models
    @verified_models ||= scope.group(:model_key, :model_slug)
      .having(
        "COUNT(DISTINCT instance_digest) >= ? AND COUNT(DISTINCT submitted_ip_digest) >= ?",
        Report::ESTABLISHED_MACHINES, Report::ESTABLISHED_NETWORKS
      )
      .count.size
  end

  def by_vendor(limit: 6) = fold(tally(:vendor), limit)
  def by_chassis(limit: 6)
    other = chassis_kinds.find { |row| row.label == "Other" }&.count.to_i
    named = chassis_kinds.reject { |row| row.label == "Other" }
    other += named.drop(limit).sum(&:count)
    shown = named.first(limit)
    other.positive? ? shown + [ Row.new(label: "Other", count: other) ] : shown
  end

  def vendor_count = tally(:vendor).size
  def chassis_count = chassis_kinds.size

  def cpu_vendors = tally(:cpu_vendor)
  def architectures = tally(:cpu_arch)
  def channels = tally(:omarchy_channel)

  def versions
    tally(:omarchy_version).sort_by { |row| [ version_key(row.label), row.label ] }.reverse
  end

  def recent_versions(limit: 6) = fold(versions, limit, other: "Older")
  def version_count = tally(:omarchy_version).size

  def memory = bucketed(:memory_bytes, MEMORY_EDGES, MEMORY_LABELS)
  def cores = bucketed(:cpu_cores, CORE_EDGES, CORE_LABELS)

  # A machine with two GPUs lands in two vendors, and in one if both match.
  def gpu_vendors
    @gpu_vendors ||= scope
      .joins("CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(reports.gpus) = 'array' THEN reports.gpus ELSE '[]'::jsonb END) AS gpu")
      .where("COALESCE(gpu ->> 'vendor', '') <> ''")
      .group(Arel.sql("LOWER(gpu ->> 'vendor')"))
      .pluck(Arel.sql("MIN(gpu ->> 'vendor')"), distinct_machines)
      .then { |pairs| rows_from(pairs) }
  end

  def security
    [
      Row.new(label: "UEFI", count: flagged(:uefi), of: machines),
      Row.new(label: "Secure Boot on", count: flagged(:secure_boot_enabled), of: machines),
      Row.new(label: "TPM present", count: flagged(:tpm_present), of: machines)
    ]
  end

  # Cumulative machines at the end of each week (Monday start), oldest first,
  # without the empty weeks before the first machine.
  def growth(weeks: 26)
    this_week = Date.current.beginning_of_week
    start = this_week - (weeks - 1).weeks
    window_start = start.in_time_zone.beginning_of_day
    created = Report.arel_table[:created_at]
    week = Arel::Nodes::NamedFunction.new("DATE_TRUNC", [ Arel::Nodes.build_quoted("week"), created ])

    running = scope.where(created_at: ...window_start).distinct.count(:instance_digest)
    added = scope.where(created_at: window_start..).group(week).pluck(week, distinct_machines)
      .to_h { |time, count| [ time.to_date, count ] }

    points = (0...weeks).map do |offset|
      day = start + offset.weeks
      running += added.fetch(day, 0)
      Point.new(week: day, total: running)
    end
    points.drop_while { |point| point.total.zero? }
  end

  private
    attr_reader :scope

    def distinct_machines = Report.arel_table[:instance_digest].count(true)

    # Case-insensitive, so "LENOVO" and "Lenovo" are one vendor. The label is
    # the first spelling alphabetically.
    def tally(column)
      @tallies ||= {}
      @tallies[column] ||= begin
        attribute = Report.arel_table[column]
        key = Arel::Nodes::NamedFunction.new("LOWER", [ attribute ])
        scope.where.not(column => [ nil, "" ]).group(key).pluck(attribute.minimum, distinct_machines)
          .then { |pairs| rows_from(pairs) }
      end
    end

    # Numbers are named and merged; text from a report is kept as sent.
    def chassis_kinds
      @chassis_kinds ||= tally(:chassis)
        .each_with_object(Hash.new(0)) { |row, kinds| kinds[chassis_label(row.label)] += row.count }
        .map { |label, count| Row.new(label: label, count: count) }
        .sort_by { |row| [ -row.count, row.label.downcase ] }
    end

    def chassis_label(raw)
      text = raw.to_s.strip
      text.match?(/\A\d+\z/) ? CHASSIS_GROUPS.fetch(text.to_i & 0x7F, "Other") : text
    end

    def rows_from(pairs)
      pairs.map { |label, count| Row.new(label: label, count: count) }
        .sort_by { |row| [ -row.count, row.label.downcase ] }
    end

    def fold(rows, limit, other: "Other")
      rest = rows.drop(limit).sum(&:count)
      rows = rows.first(limit)
      rest.positive? ? rows + [ Row.new(label: other, count: rest) ] : rows
    end

    # Fixed categories, in size order, so a chart keeps its shape as data grows.
    # The sanitizer stores a missing value as 0, which would otherwise land in the smallest bucket.
    def bucketed(column, edges, labels)
      attribute = Report.arel_table[column]
      index = edges.each_with_index.inject(Arel::Nodes::Case.new) { |kase, (edge, i)| kase.when(attribute.lteq(edge)).then(i) }
        .else(edges.size)
      by_index = scope.where(column => 1..).group(index).pluck(index, distinct_machines).to_h
      labels.each_with_index.map { |label, i| Row.new(label: label, count: by_index.fetch(i, 0)) }
    end

    def flagged(column)
      scope.where(column => true).distinct.count(:instance_digest)
    end

    def version_key(label)
      Gem::Version.new(label)
    rescue ArgumentError
      Gem::Version.new("0")
    end
end
