module Spree
  module Marketing
    module SmartList
      class LeastZoneWiseOrders < Base

        TIME_FRAME = 1.month

        def initialize zone_id, list_uid = nil
          @zone_id = zone
          super(TIME_FRAME, list_uid)
        end

        def query
          Spree::Order.includes(:user, ship_address: [:country, :state])
                      .where.not(user_id: nil)
                      .where("spree_states.id = ?", @state_id)
                      .where("spree_orders.completed_at >= :time_frame", time_frame: computed_time_frame)
                      .group(:email)
                      .order("COUNT(spree_orders.id)")
                      .references(:ship_address)
                      .map { |order| order.user }
        end

        def self.process
          # Reports::MostActiveZones.new.query.each do |zone|

          # end
        end
      end
    end
  end
end