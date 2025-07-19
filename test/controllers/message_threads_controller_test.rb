require "test_helper"

class MessageThreadsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get message_threads_index_url
    assert_response :success
  end
end
