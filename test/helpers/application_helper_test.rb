require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "machines_ran_omarchy uses spoken machine counts" do
    assert_equal "1 machine reported running Omarchy.", machines_ran_omarchy(1)
    assert_equal "3 machines reported running Omarchy.", machines_ran_omarchy(3)
  end
end
