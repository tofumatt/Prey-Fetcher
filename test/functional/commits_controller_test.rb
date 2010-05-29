require 'test_helper'

class CommitsControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:commits)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create commit" do
    assert_difference('Commit.count') do
      post :create, :commit => { }
    end

    assert_redirected_to commit_path(assigns(:commit))
  end

  test "should show commit" do
    get :show, :id => commits(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => commits(:one).to_param
    assert_response :success
  end

  test "should update commit" do
    put :update, :id => commits(:one).to_param, :commit => { }
    assert_redirected_to commit_path(assigns(:commit))
  end

  test "should destroy commit" do
    assert_difference('Commit.count', -1) do
      delete :destroy, :id => commits(:one).to_param
    end

    assert_redirected_to commits_path
  end
end
