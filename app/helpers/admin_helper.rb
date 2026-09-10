module AdminHelper
  def admin_nav_class(path)
    current = request.path == path
    base = "no-underline hover:text-accent"
    current ? "#{base} text-accent" : "#{base} text-paper"
  end
end
