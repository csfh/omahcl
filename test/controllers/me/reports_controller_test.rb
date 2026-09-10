require "test_helper"

class Me::ReportsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as(users(:one)) }

  test "empty state offers a copyable collector command" do
    get me_reports_path

    assert_response :success
    assert_select "h1", "My machines"
    assert_select "[data-controller=clipboard]"
    assert_select "[data-clipboard-target=source]", text: /curl -fsSL .+\/collect \| bash/
    assert_select "button[type=button][data-action='clipboard#copy']", text: "Copy"
  end
end
