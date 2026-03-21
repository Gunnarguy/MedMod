require 'xcodeproj'

project_path = '/Users/gunnarhostetler/Documents/GitHub/MedMod/MedMod.xcodeproj'
project = Xcodeproj::Project.open(project_path)
target = project.targets.first

Dir.glob('/Users/gunnarhostetler/Documents/GitHub/MedMod/MedMod/**/*.swift').each do |file_path|
  # Skip if already in project
  next if target.source_build_phase.files.any? { |f| f.file_ref && f.file_ref.real_path.to_s == file_path }

  relative_path = file_path.sub('/Users/gunnarhostetler/Documents/GitHub/MedMod/MedMod/', '')
  parts = relative_path.split('/')
  filename = parts.pop

  current_group = project.main_group.groups.find { |g| g.name == 'MedMod' || g.path == 'MedMod' }
  parts.each do |part|
    next_group = current_group.groups.find { |g| g.name == part || g.path == part }
    if next_group.nil?
      next_group = current_group.new_group(part)
    end
    current_group = next_group
  end

  # We add the file relative to the group
  file_ref = current_group.new_file(filename)
  target.add_file_references([file_ref])
  puts "Added to project: #{file_path}"
end

project.save
puts "Project updated!"
