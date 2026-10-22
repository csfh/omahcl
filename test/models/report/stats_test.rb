require "test_helper"

class Report::StatsTest < ActiveSupport::TestCase
  GIB = 1024**3

  # Each call is a new machine unless the digest is passed.
  def add(digest: nil, version: "4.0.2", channel: "stable", vendor: "LENOVO",
          product: "ThinkPad X220", chassis: "Notebook", cpu_vendor: "Intel", arch: "x86_64", cores: 2,
          memory_gib: 8, gpus: [ { "vendor" => "Intel", "name" => "HD" } ], uefi: true, tpm: false, secure_boot: false)
    payload = omarchy_payload(product: product, **(digest ? { instance_digest: digest } : {}))
    payload["omarchy"] = { "version" => version, "channel" => channel }
    payload["hardware"].merge!(
      "vendor" => vendor, "chassis" => chassis, "memory_bytes" => (memory_gib * GIB).to_i, "gpus" => gpus,
      "uefi" => uefi, "tpm" => { "present" => tpm }, "secure_boot" => { "enabled" => secure_boot }
    )
    payload["hardware"]["cpu"] = { "model" => "CPU", "vendor" => cpu_vendor, "arch" => arch, "cores" => cores }
    ingest_report!(payload)
  end

  def stats = Report::Stats.new

  def counts(rows) = rows.to_h { |row| [ row.label, row.count ] }

  test "a scope narrows every figure, and is still limited to visible machines" do
    add(product: "X220")
    add(product: "X220", memory_gib: 16).update!(hidden_at: Time.current)
    add(product: "X230")

    one_model = Report::Stats.new(Report.where(model_slug: "lenovo-x220"))

    assert_equal 1, one_model.machines
    assert_equal({ "8 GB" => 1 }, counts(one_model.memory).select { |_, count| count.positive? })
  end

  test "an empty database gives zeros and no rows" do
    assert_equal 0, stats.machines
    assert_equal 0, stats.models
    assert_empty stats.by_vendor
    assert_empty stats.growth
  end

  test "hidden machines are never counted" do
    add
    add(product: "X230").update!(hidden_at: Time.current)

    assert_equal 1, stats.machines
    assert_equal 1, stats.models
    assert_equal({ "Lenovo" => 1 }, counts(stats.by_vendor))
  end

  test "a machine that reports again counts once" do
    digest = ::Digest::SHA256.hexdigest("same machine")
    3.times { add(digest: digest) }

    assert_equal 1, stats.machines
    assert_equal({ "Lenovo" => 1 }, counts(stats.by_vendor))
  end

  test "counts machines and models" do
    3.times { add }
    2.times { add(product: "X230") }

    assert_equal 5, stats.machines
    assert_equal 2, stats.models
  end

  test "vendors merge across letter case and the rest fold into Other" do
    add(vendor: "LENOVO")
    add(vendor: "Lenovo")
    add(vendor: "Dell")
    %w[A B C D E F].each { |name| add(vendor: name) }

    # Ties break alphabetically, ignoring case.
    # The merged label is whichever spelling the database collates first.
    rows = counts(stats.by_vendor(limit: 3)).transform_keys(&:downcase)
    assert_equal({ "lenovo" => 2, "a" => 1, "b" => 1, "other" => 5 }, rows)
    assert_equal 8, stats.vendor_count
  end

  # The collector sends the raw DMI chassis_type number (SMBIOS spec), not a name.
  test "chassis numbers are named and grouped, and unknown ones fall under Other" do
    %w[9 10 14].each { |type| add(chassis: type) }
    add(chassis: "3")
    add(chassis: "35")
    add(chassis: "2")
    add(chassis: "99")
    add(chassis: "138") # bit 7 is the chassis lock flag, so this is 10 again

    assert_equal({ "Laptop" => 4, "Desktop" => 1, "Mini PC" => 1, "Other" => 2 }, counts(stats.by_chassis))
    assert_equal 4, stats.chassis_count
  end

  test "chassis text is kept as sent and a blank one is left out" do
    add(chassis: "Notebook")
    add(chassis: nil)

    assert_equal({ "Notebook" => 1 }, counts(stats.by_chassis))
  end

  test "extra chassis kinds fold into the one Other row" do
    add(chassis: "1")
    add(chassis: "Alpha")
    add(chassis: "Beta")
    add(chassis: "Gamma")

    assert_equal({ "Alpha" => 1, "Beta" => 1, "Other" => 2 }, counts(stats.by_chassis(limit: 2)))
  end

  test "memory is bucketed to the next common size" do
    [ 2, 3.8, 7.4, 15.2, 16, 31, 63, 128 ].each { |gib| add(memory_gib: gib) }

    assert_equal(
      { "4 GB or less" => 2, "8 GB" => 1, "16 GB" => 2, "32 GB" => 1, "64 GB" => 1, "More than 64 GB" => 1 },
      counts(stats.memory)
    )
  end

  test "machines that sent no memory or core count are left out of those charts" do
    add(memory_gib: 0, cores: 0)
    add(memory_gib: 8, cores: 4)

    assert_equal 1, counts(stats.memory).values.sum
    assert_equal 1, counts(stats.cores).values.sum
    assert_equal 2, stats.machines
  end

  test "core counts are bucketed" do
    [ 1, 2, 4, 6, 8, 12, 16, 24 ].each { |cores| add(cores: cores) }

    assert_equal(
      { "1–2" => 2, "3–4" => 1, "5–8" => 2, "9–16" => 2, "17 or more" => 1 },
      counts(stats.cores)
    )
  end

  test "a machine counts once per GPU vendor, however many GPUs it has" do
    add(gpus: [ { "vendor" => "Intel" }, { "vendor" => "NVIDIA" } ])
    add(gpus: [ { "vendor" => "NVIDIA" }, { "vendor" => "NVIDIA" } ])
    add(gpus: [])

    assert_equal({ "NVIDIA" => 2, "Intel" => 1 }, counts(stats.gpu_vendors))
  end

  test "versions sort as version numbers, not text" do
    add(version: "4.0.10")
    add(version: "4.0.2")
    add(version: "4.0.2")
    add(version: "not-a-version")

    assert_equal [ "4.0.10", "4.0.2", "not-a-version" ], stats.versions.map(&:label)
    assert_equal 3, stats.version_count
  end

  test "recent versions fold older ones together" do
    %w[4.0.5 4.0.4 4.0.3 4.0.2 4.0.1].each { |version| add(version: version) }
    add(version: "4.0.1")

    assert_equal({ "4.0.5" => 1, "4.0.4" => 1, "4.0.3" => 1, "Older" => 3 }, counts(stats.recent_versions(limit: 3)))
  end

  test "channels are counted" do
    add(channel: "stable")
    add(channel: "stable")
    add(channel: "edge")

    assert_equal({ "stable" => 2, "edge" => 1 }, counts(stats.channels))
  end

  test "boot and security shares are of all visible machines" do
    add(uefi: true, tpm: true, secure_boot: true)
    add(uefi: true, tpm: true, secure_boot: false)
    add(uefi: false, tpm: false, secure_boot: false)
    add(uefi: true, tpm: false, secure_boot: false)

    shares = stats.security.to_h { |row| [ row.label, [ row.count, row.of ] ] }
    assert_equal({ "UEFI" => [ 3, 4 ], "Secure Boot on" => [ 1, 4 ], "TPM present" => [ 2, 4 ] }, shares)
  end

  test "CPU vendors and architectures are counted" do
    add(cpu_vendor: "Intel")
    add(cpu_vendor: "AMD", arch: "x86_64")
    add(cpu_vendor: "Apple", arch: "arm64")

    assert_equal({ "Intel" => 1, "AMD" => 1, "Apple" => 1 }, counts(stats.cpu_vendors))
    assert_equal({ "x86_64" => 2, "arm64" => 1 }, counts(stats.architectures))
  end

  test "raw vendor_id strings are named and merged with the names the collector sends" do
    add(cpu_vendor: "GenuineIntel")
    add(cpu_vendor: "Intel")
    add(cpu_vendor: "AuthenticAMD")
    add(cpu_vendor: "Apple", arch: "aarch64")

    assert_equal({ "Intel" => 2, "AMD" => 1, "Apple" => 1 }, counts(stats.cpu_vendors))
  end

  test "growth is cumulative by week and keeps weeks with no new machines" do
    travel_to Time.utc(2026, 9, 1, 12) do   # a Tuesday
      add
      add
    end
    travel_to Time.utc(2026, 9, 22, 12) do  # three weeks later
      add
    end

    travel_to Time.utc(2026, 9, 23, 12) do
      points = stats.growth(weeks: 4)

      assert_equal [ 2, 2, 2, 3 ], points.map(&:total)
      assert_equal Date.new(2026, 8, 31), points.first.week
      assert_equal Date.new(2026, 9, 21), points.last.week
    end
  end

  test "the last growth point is every visible machine" do
    travel_to(Time.utc(2026, 1, 5, 23, 30)) { add }
    travel_to(Time.utc(2026, 9, 20, 23, 59)) { add } # Sunday night, still last week's column
    add

    assert_equal stats.machines, stats.growth.last.total
  end

  test "a malformed gpus value does not break the GPU chart" do
    add(gpus: [ { "vendor" => "AMD" } ])
    Report.last.update_columns(gpus: { "vendor" => "oops" })
    add(gpus: [ { "vendor" => "Intel" } ])

    assert_equal({ "Intel" => 1 }, counts(stats.gpu_vendors))
  end

  test "growth starts from the machines that came before its window" do
    travel_to(Time.utc(2026, 6, 1)) { add }
    travel_to(Time.utc(2026, 9, 23, 12)) do
      add

      assert_equal [ 1, 1, 2 ], stats.growth(weeks: 3).map(&:total)
    end
  end
end
