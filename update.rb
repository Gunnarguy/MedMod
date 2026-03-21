require 'xcodeproj'
project = Xcodeproj::Project.open('/Users/gunnarhostetler/Documents/GitHub/MedMod/MedMod.xcodeproj')
target = project.targets.first

# recursively add all swift files from MedMod directory
# We can just use the project's root group instead of searching for MedMod group to avoid nil errors.
main_group = project.main_group.groups.find { |g| g.path == 'MedMod' || g.name == 'MedMod' }
if main_group.nil?
  puts "MedMod group not found! Using main_group"
  main_group = project.main_group
end

Dir.glob('/Users/gunnarhostetler/Documents/GitHub/MedMod/MedMod/**/*.swift').each do |file_path|
  next if target.source_build_phase.files.any? { |f| f.file_ref && f.file_ref.real_path.to_s == file_path }
  
  # Just add them as a flat file reference for compilation purposes to avoid group logic crashes
  file_ref = main_group.new_reference(file_path)
  target.add_file_references([file_ref])
  puts "Added #{file_path}"
end

project.save
