require "test_helper"

class Admin::ChallengesControllerTest < ActionDispatch::IntegrationTest
  test "non-admin is redirected" do
    sign_in_as(users(:one))
    get admin_challenges_path
    assert_redirected_to root_path
  end

  test "admin can list and open a challenge without seeing the ip digest" do
    nonce, challenge = Challenge.issue!(ip: "203.0.113.10")
    Challenge.consume!(nonce)

    sign_in_as(users(:admin))
    get admin_challenges_path

    assert_response :success
    assert_select "h1", "Challenges"
    assert_select "a", text: "Challenge #{challenge.id}"
    assert_select "p", /Consumed/
    assert_no_match(/issued_ip/, response.body)
    assert_no_match(challenge.issued_ip_digest, response.body)

    get admin_challenge_path(challenge)

    assert_response :success
    assert_select "h1", "Challenge #{challenge.id}"
    assert_match(/Consumed/, response.body)
    assert_match(challenge.nonce_digest, response.body)
    assert_no_match(/issued_ip/, response.body)
    assert_no_match(challenge.issued_ip_digest, response.body)
  end

  test "admin can filter to open challenges" do
    _used_nonce, used = Challenge.issue!(ip: "203.0.113.10")
    Challenge.consume!(_used_nonce)
    _open_nonce, open_challenge = Challenge.issue!(ip: "203.0.113.11")

    sign_in_as(users(:admin))
    get admin_challenges_path, params: { status: "open" }

    assert_response :success
    assert_select "a", text: "Challenge #{open_challenge.id}"
    assert_select "a", text: "Challenge #{used.id}", count: 0
  end
end
