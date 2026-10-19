module ApplicationHelper
  def page_title(title)
    content_for(:title, "#{title} · Omarchy HCL")
  end

  def collect_command
    "curl -fsSL #{root_url.chomp('/')}/collect | bash"
  end

  def delete_command
    "curl -fsSL #{root_url.chomp('/')}/delete | bash"
  end

  def memory_label(bytes)
    number_to_human_size(bytes.to_i)
  end

  # spacing: false for fields laid out in a flex row, where the stacked-form
  # top margin would push the field below its sibling button.
  def field_class(spacing: true)
    base = "block w-full border-2 border-line bg-ink px-3 py-2 text-paper placeholder:text-paper/40 focus:border-accent focus:outline-2 focus:outline-offset-2 focus:outline-accent"
    spacing ? "mt-2 #{base}" : base
  end

  def button_class
    "inline-flex cursor-pointer items-center border-2 border-accent bg-accent px-3.5 py-2 text-sm font-semibold text-ink no-underline hover:border-paper hover:bg-paper hover:no-underline active:translate-y-px focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-paper"
  end

  def machines_ran_omarchy(count)
    "#{pluralize(count, "machine")} reported running Omarchy."
  end

  def machines_status(machines)
    render "application/machines_status", machines: machines.to_i
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
    "inline-flex items-center border-2 border-accent px-3.5 py-2 text-sm text-accent no-underline hover:bg-accent/10 hover:no-underline active:translate-y-px focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-paper"
  end
end
