class Payment < ApplicationRecord
  belongs_to :user
  belongs_to :user_enrollment, optional: true

  # 할인 항목 정의
  DISCOUNT_TYPES = {
    'friend_referral' => { name: '친구 추천', amount: 50000 },
    'video_review' => { name: '영상 후기', amount: 50000 },
    'text_review' => { name: '텍스트 후기', amount: 50000 },
    'two_subjects' => { name: '2과목 수강', amount: 50000 },
    'three_subjects' => { name: '3과목 수강', amount: 100000 }
  }.freeze

  def discount_details
    return [] unless discount_items.present?

    discount_items.map do |item|
      DISCOUNT_TYPES[item]
    end.compact
  end

  def total_discount
    discount_amount || 0
  end
end
