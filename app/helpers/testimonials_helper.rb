module TestimonialsHelper
  def truncate_testimonial(testimonial, length = 180)
    return "" if testimonial.blank?
    
    if testimonial.length > length
      truncated = testimonial[0..length].gsub(/\s\w+\s*$/, '...')
    else
      testimonial
    end
  end
end