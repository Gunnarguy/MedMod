require 'xcodeproj'
project = Xcodeproj::Project.open('/Users/gunnarhostetler/Documents/GitHub/MedMod/MedMod.xcodeproj')
target = project.targets.first

main_group = project.main_group.groups.find { |g| g.path == 'MedMod' || g.name == 'MedMod' }
if main_group.nil?
  main_group = project.main_group
end

Dir.glob('/Users/gunnarhostetler/Documents/GitHub/MedMod/MedMod/**/*.swift').each do |file_path|
  # Avoid adding if already added
  next if target.source_build_phase.files.any? { |f| f.file_ref && f.file_ref.real_path.to_s == file_path }

  file_ref = main_group.new_reference(file_path)
  target.add_file_references([file_ref])
  puts "Added #{file_path}"
end

project.save
puts "Done updating project."
