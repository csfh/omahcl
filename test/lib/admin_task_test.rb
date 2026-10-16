require "test_helper"
require "rake"

class AdminTaskTest < ActiveSupport::TestCase
  setup do
    Rails.application.load_tasks unless Rake::Task.task_defined?("admin:create")
    Rake::Task["admin:create"].reenable
  end

  test "creates an admin with the given password" do
    with_env("EMAIL" => "New.Admin@example.com", "PASSWORD" => "correct horse battery") do
      capture_io { Rake::Task["admin:create"].invoke }
    end

    user = User.find_by!(email_address: "new.admin@example.com")
    assert user.admin?
    assert user.authenticate("correct horse battery")
  end

  test "resets the password of an existing account and makes it an admin" do
    with_env("EMAIL" => users(:one).email_address, "PASSWORD" => "a brand new password") do
      capture_io { Rake::Task["admin:create"].invoke }
    end

    assert users(:one).reload.admin?
    assert users(:one).authenticate("a brand new password")
  end

  test "prints a generated password when none is given" do
    out, _err = with_env("EMAIL" => "gen@example.com", "PASSWORD" => nil) do
      capture_io { Rake::Task["admin:create"].invoke }
    end

    generated = out[/Password: (\S+)/, 1]
    assert generated
    assert User.find_by!(email_address: "gen@example.com").authenticate(generated)
  end

  private
    def with_env(vars)
      old = vars.keys.index_with { |key| ENV[key] }
      vars.each { |key, value| ENV[key] = value }
      yield
    ensure
      old.each { |key, value| ENV[key] = value }
    end
end
