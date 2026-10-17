require "test_helper"

class CollectsControllerTest < ActionDispatch::IntegrationTest
  # The test environment allows every host, as production would without config.hosts.
  test "collect serves no script for a host that could inject shell code" do
    get collect_path, headers: { "X-Forwarded-Host" => "x}$(id)" }

    assert_response :bad_request
    refute_includes response.body, "#!/usr/bin/env bash"
  end
end
