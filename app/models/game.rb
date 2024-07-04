class Game < ApplicationRecord
  validate do |game|
    if game.human_you_name.blank? && game.pest_you_name.blank?
      errors.add(:base, '人間側と害虫側の両方がAIなのはダメです')
    end
  end
end
