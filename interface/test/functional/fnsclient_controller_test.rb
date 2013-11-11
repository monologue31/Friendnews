require 'test_helper'

class FnsclientControllerTest < ActionController::TestCase
  test "should get post" do
    get :post
    assert_response :success
  end

  test "should get control" do
    get :control
    assert_response :success
  end

end
