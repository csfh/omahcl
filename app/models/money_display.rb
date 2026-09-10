class MoneyDisplay
  def initialize(cents, currency)
    @cents = cents
    @currency = currency.presence || "USD"
  end

  def to_s
    amount = ActiveSupport::NumberHelper.number_to_delimited(format("%.2f", @cents / 100.0))
    "#{amount} #{@currency}"
  end
end
