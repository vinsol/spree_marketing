FactoryGirl.define do

  factory :marketing_page_event, class: Spree::PageEvent do
    actor_type Spree.user_class
    actor_id 1
    session_id { Faker::Number.number(16) }
    activity "index"
  end

  factory :marketing_search_page_event, class: Spree::PageEvent do
    actor_type Spree.user_class
    actor_id 1
    session_id { Faker::Number.number(16) }
    activity "search"
    search_keywords { Faker::Name.name }
  end

end
