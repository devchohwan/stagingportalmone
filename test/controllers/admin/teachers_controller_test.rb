require "test_helper"

class Admin::TeachersControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get admin_teachers_index_url
    assert_response :success
  end
end
