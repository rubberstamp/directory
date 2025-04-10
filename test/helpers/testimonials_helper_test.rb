require "test_helper"

class TestimonialsHelperTest < ActionView::TestCase
  include TestimonialsHelper

  test "truncate_testimonial should truncate long text" do
    long_testimonial = "This is a very long testimonial that should be truncated because it exceeds the default length limit of 180 characters. This text will continue to be quite lengthy so that we can ensure our truncation function is working properly."
    truncated = truncate_testimonial(long_testimonial)
    assert truncated.length < long_testimonial.length
    assert truncated.end_with?("...")
  end

  test "truncate_testimonial should not truncate short text" do
    short_testimonial = "This is a short testimonial."
    assert_equal short_testimonial, truncate_testimonial(short_testimonial)
  end

  test "truncate_testimonial should handle nil input" do
    assert_equal "", truncate_testimonial(nil)
  end
end
