[ "General", "Ruby", "API" ].each do |name|
  ExampleCategory.find_or_create_by!(name: name)
  ExampleTag.find_or_create_by!(name: name)
end
