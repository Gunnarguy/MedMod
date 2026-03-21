require 'xcodeproj'
project = Xcodeproj::Project.open('/Users/gunnarhostetler/Documents/GitHub/MedMod/MedMod.xcodeproj')
target = project.targets.first

# Fix Duplicate Info.plist
# Info.plist should not be in Copy Bundle Resources if it is set as INFOPLIST_FILE
target.resources_build_phase.files.dup.each do |file|
  if file.file_ref && file.file_ref.path && (file.file_ref.path.include?('Info.plist'))
    file.remove_from_project
  end
end

seen_usdz = false
target.resources_build_phase.files.dup.each do |file|
  if file.file_ref && file.file_ref.path && file.file_ref.path.include?('FemaleHeadModel.usdz')
    if seen_usdz
      file.remove_from_project
    else
      seen_usdz = true
    end
  end
end

project.save
