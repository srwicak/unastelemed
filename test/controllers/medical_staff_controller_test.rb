require "test_helper"

class MedicalStaffControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get medical_staff_index_url
    assert_response :success
  end

  test "should get show" do
    get medical_staff_show_url
    assert_response :success
  end

  test "should get doctors" do
    get medical_staff_doctors_url
    assert_response :success
  end

  test "should get nurses" do
    get medical_staff_nurses_url
    assert_response :success
  end
end
