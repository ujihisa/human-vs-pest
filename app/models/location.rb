# frozen_string_literal: true

# +→ x
# ↓
# y
#
# 二次元配列で表現するときは必ずy, xの順になる点に注意
Location = Data.define(:x, :y) do
  def inspect
    "(#{x}, #{y})"
  end
end

