class MoneyDisplay
  def initialize(cents, currency)
    @cents = cents
    @currency = currency.presence || "USD"
  end

  def to_s
    amount = format("%.2f", @cents / 100.0)
    "#{amount} #{@currency}"
  end
end
