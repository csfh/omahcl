require "test_helper"

class JsonCompatTest < ActiveSupport::TestCase
  test "ActiveSupport::JSON.decode accepts a positional options hash on json 3" do
    assert_equal({ "ok" => true }, ActiveSupport::JSON.decode('{"ok":true}', {}))
  end

  test "password reset tokens verify through MessageVerifier JSON payload" do
    user = users(:one)

    assert_equal user, User.find_by_password_reset_token!(user.password_reset_token)
  end

  test "report jsonb columns round-trip after ingest" do
    report, _token = ingest_report!

    reloaded = Report.find(report.id)
    assert_equal [ { "vendor" => "Intel", "name" => "HD Graphics 3000" } ], reloaded.gpus
    assert_kind_of Hash, reloaded.facts
  end
end
