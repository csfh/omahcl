module AdminHelper
  def admin_nav_class(path)
    current = request.path == path
    base = "inline-flex min-h-11 items-center no-underline hover:text-accent active:text-accent"
    current ? "#{base} text-accent" : "#{base} text-paper"
  end
end
