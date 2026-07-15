# frozen_string_literal: true

FactoryBot.define do
  factory :example_category do
    sequence(:name) { |number| "Category #{number}" }
  end

  factory :example_tag do
    sequence(:name) { |number| "Tag #{number}" }
  end

  factory :example do
    sequence(:title) { |number| "Example #{number}" }
    description { nil }
    status { "draft" }
    score { 0 }

    trait :with_category do
      association :category, factory: :example_category
    end

    trait :with_tags do
      transient do
        tags_count { 2 }
      end

      after(:create) do |example, evaluator|
        create_list(:example_tag, evaluator.tags_count).each do |tag|
          create(:example_tagging, example: example, example_tag: tag)
        end
      end
    end
  end

  factory :example_tagging do
    association :example
    association :example_tag
  end
end
