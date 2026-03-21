require 'xcodeproj'
project = Xcodeproj::Project.open('/Users/gunnarhostetler/Documents/GitHub/MedMod/MedMod.xcodeproj')
target = project.targets.first

# Add entitlements and plist to the main group if not present
main_group = project.main_group.groups.find { |g| g.path == 'MedMod' || g.name == 'MedMod' }
if main_group.nil?
  main_group = project.main_group
end

entitlements_path = 'MedMod/MedMod.entitlements'
plist_path = 'MedMod/Info.plist'

unless main_group.files.any? { |f| f.path == 'MedMod.entitlements' }
  main_group.new_reference('MedMod.entitlements')
end

unless main_group.files.any? { |f| f.path == 'Info.plist' }
  main_group.new_reference('Info.plist')
end

# Update build settings
target.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = entitlements_path
  config.build_settings['INFOPLIST_FILE'] = plist_path
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
end

project.save
puts "Entitlements and Info.plist added."
