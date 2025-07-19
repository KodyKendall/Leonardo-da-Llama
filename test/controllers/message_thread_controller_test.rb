require "test_helper"

class MessageThreadControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get message_thread_index_url
    assert_response :success
  end
end
