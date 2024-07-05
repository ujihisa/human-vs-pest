class GameMatch < ApplicationRecord
  validate do |game_match|
    if game_match.human_you_name.blank? && game_match.pest_you_name.blank?
      errors.add(:base, '人間側と害虫側の両方がAIなのはダメです')
    end
  end
end
