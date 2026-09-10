module ApplicationHelper
  def page_title(title)
    content_for(:title, "#{title} · Market")
  end

  def collect_command
    "curl -fsSL #{root_url.chomp('/')}/collect | bash"
  end

  def memory_label(bytes)
    number_to_human_size(bytes.to_i)
  end

  # spacing: false for fields laid out in a flex row, where the stacked-form
  # top margin would push the field below its sibling button.
  def field_class(spacing: true)
    base = "block w-full rounded-md border border-white/15 bg-white/5 px-3 py-2 text-paper placeholder:text-paper/40 focus:border-accent focus:outline-2 focus:outline-offset-2 focus:outline-accent"
    spacing ? "mt-2 #{base}" : base
  end

  def button_class
    "inline-flex cursor-pointer items-center rounded-md bg-accent px-3.5 py-2 text-sm font-medium text-ink hover:bg-accent/90"
  end

  def evidence_label(claimants)
    if Report.established?(claimants)
      "Verified"
    else
      "Only a few people so far"
    end
  end

  def people_ran_omarchy(count)
    "#{pluralize(count, "person")} #{count == 1 ? "has" : "have"} run Omarchy on this machine."
  end

  def listing_kind_label(listing)
    listing.donation? ? "Donation" : "For sale"
  end

  def listing_condition_label(listing)
    listing.condition.to_s.titleize.presence
  end

  def claimants_status(claimants)
    render "application/claimants_status", claimants: claimants.to_i
  end

  def inline_icon(paths, title:)
    tag.svg(
      xmlns: "http://www.w3.org/2000/svg",
      fill: "none",
      viewBox: "0 0 24 24",
      "stroke-width": 1.5,
      stroke: "currentColor",
      class: "size-4 shrink-0",
      "aria-hidden": true,
      title: title
    ) do
      safe_join(Array(paths).map { |d| tag.path(d:, "stroke-linecap": "round", "stroke-linejoin": "round") })
    end
  end

  def ghost_button_class
    "inline-flex items-center rounded-md border border-white/15 px-3.5 py-2 text-sm text-paper hover:bg-white/5"
  end
end
