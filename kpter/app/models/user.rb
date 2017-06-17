class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable,
         :confirmable, :omniauthable
  has_many :community_users
  has_many :tcard_assignees
  has_many :t_card, :through => :tcard_assignees
  validates :username, presence: true

  class << self
    def find_communities_with_user_id(user_id)
      User.includes([{ :community_users => :community }])
        .references(:community_users).order("communities.id DESC")
        .where("community_users.user_id = ?", user_id)
        .map { |u| u.community_users.map { |cu| cu.community }}
        .flatten
    end

    def find_tcards_with_user_id(user_id, status = TCard.status.open)
      User.joins([:tcard_assignees => :t_card])
        .includes([:tcard_assignees => :t_card])
        .where("tcard_assignees.user_id = ?", user_id)
        .where("t_cards.status = ?", status)
        .map { |u| u.tcard_assignees.map{ |ta| ta.t_card } }
        .flatten
        .sort_by!{ |t| [t[:deadline].nil? ? Date.new(9999, 12, 31) : t[:deadline], t[:id]]}  # 期限日の近い順 (同じ期限日内ではIDの昇順。未設定の場合(nil)は常に最後尾)
    end

    def find_all_tcards_with_user_id(user_id)
      User.joins([:tcard_assignees => :t_card])
        .includes([:tcard_assignees => :t_card])
        .where("tcard_assignees.user_id = ?", user_id)
        .map { |u| u.tcard_assignees.map{ |ta| ta.t_card } }
        .flatten
        .sort_by!{ |t| [t[:deadline].nil? ? Date.new(9999, 12, 31) : t[:deadline], t[:id]]}
    end

    def find_invitable_users(community)
      User.where("
      id NOT IN (
        SELECT
          users.id
        FROM
          users
		      INNER JOIN community_users ON
			       users.id = community_users.user_id
             and community_users.community_id = ?
		  )
      AND confirmed_at IS NOT NULL", community.id)
      .order("users.id")
      # XXX 自分が追加する確率、頻度が高いユーザーを上にだす。同じ部屋に入っている部屋数。個人チャット数。などなど。
    end
  end

  def joining?(community)
    CommunityUser.where("user_id = ? and community_id = ?", id, community.id).present?
  end

  def join_in(community)
    CommunityUser.create(
      community_id: community.id,
      user_id: self.id
    )
  end
end
