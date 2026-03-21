require 'xcodeproj'
project = Xcodeproj::Project.open('/Users/gunnarhostetler/Documents/GitHub/MedMod/MedMod.xcodeproj')
target = project.targets.first
main_group = project.main_group.groups.find { |g| g.path == 'MedMod' || g.name == 'MedMod' } || project.main_group
file_ref = main_group.new_reference('FemaleHeadModel.usdz')
target.resources_build_phase.add_file_reference(file_ref)
project.save
