require "test_helper"

class CollectsControllerTest < ActionDispatch::IntegrationTest
  # The test environment allows every host, as production would without config.hosts.
  test "collect serves no script for a host that could inject shell code" do
    get collect_path, headers: { "X-Forwarded-Host" => "x}$(id)" }

    assert_response :bad_request
    refute_includes response.body, "#!/usr/bin/env bash"

    get delete_script_path, headers: { "X-Forwarded-Host" => "x}$(id)" }

    assert_response :bad_request
  end

  test "collect serves the collect action and delete serves the delete action" do
    get collect_path
    assert_includes response.body, "OMAHCL_ACTION=${OMAHCL_ACTION:-collect}"
    assert_includes response.headers["Content-Disposition"], 'filename="collect.sh"'

    get delete_script_path
    assert_response :success
    assert_includes response.body, "OMAHCL_ACTION=${OMAHCL_ACTION:-delete}"
    assert_includes response.headers["Content-Disposition"], 'filename="delete.sh"'
    refute_includes response.body, "__OMAHCL_"
  end

  test "the script name comes only from the route" do
    get collect_path, params: { script: "delete; id" }

    assert_response :success
    assert_includes response.body, "OMAHCL_ACTION=${OMAHCL_ACTION:-collect}"
  end
end
