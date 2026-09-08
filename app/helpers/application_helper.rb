module ApplicationHelper
  def page_title(title)
    content_for(:title, "#{title} · Market")
  end

  def collect_command
    "curl -fsSL #{root_url.chomp('/')}/collect | python3"
  end

  def memory_label(bytes)
    number_to_human_size(bytes.to_i)
  end

  def field_class
    "mt-2 block w-full rounded-md border border-white/15 bg-white/5 px-3 py-2 text-paper placeholder:text-paper/40 focus:border-accent focus:outline-none"
  end

  def button_class
    "inline-flex cursor-pointer items-center rounded-md bg-accent px-3.5 py-2 text-sm font-medium text-ink hover:bg-accent/90"
  end

  def ghost_button_class
    "inline-flex items-center rounded-md border border-white/15 px-3.5 py-2 text-sm text-paper hover:bg-white/5"
  end
end
