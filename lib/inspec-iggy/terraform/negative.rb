# returns negative of Terraform tfstate file coverage

require 'inspec/objects/control'
require 'inspec/objects/ruby_helper'
require 'inspec/objects/describe'

require 'inspec-iggy/file_helper'
require 'inspec-iggy/inspec_helper'
require 'inspec-iggy/terraform/generate'

module InspecPlugins::Iggy::Terraform
  class Negative
    # parse through the JSON and generate InSpec controls
    def self.parse_negative(tf_file, resource_path, platform)
      tfstate = InspecPlugins::Iggy::FileHelper.parse_json(tf_file)
      sourcefile = File.absolute_path(tf_file)

      # take those Terraform resources and map to InSpec resources by name and keep all attributes
      parsed_resources = InspecPlugins::Iggy::Terraform::Generate.parse_resources(tfstate, resource_path, platform)

      # subtract matched resources from all available resources
      negative_controls = parse_unmatched_resources(parsed_resources, sourcefile, platform)
      negative_controls += parse_matched_resources(parsed_resources, sourcefile, platform)

      negative_controls
    end

    # return controls for the iterators of things unmatched in the terraform.tfstate
    def self.parse_unmatched_resources(resources, sourcefile, platform)
      resources.extend Hashie::Extensions::DeepFind # use to find iterators' values from other attributes
      unmatched_resources = InspecPlugins::Iggy::InspecHelper.available_resource_iterators(platform).keys - resources.keys
      Inspec::Log.debug "Terraform::Negative.parse_unmatched_resources unmatched_resources #{unmatched_resources}"
      unmatched_controls = []
      unmatched_resources.each do |unmatched|
        unresources = InspecPlugins::Iggy::InspecHelper.available_resource_iterators(platform)[unmatched]
        iterator = unresources['iterator']
        ctrl = Inspec::Control.new
        ctrl.id = "NEGATIVE-COVERAGE:#{iterator}"
        ctrl.title = "InSpec-Iggy NEGATIVE-COVERAGE:#{iterator}"
        ctrl.descriptions[:default] = "NEGATIVE-COVERAGE:#{iterator} from the source file #{sourcefile}\nGenerated by InSpec-Iggy v#{InspecPlugins::Iggy::VERSION}"
        ctrl.impact = '1.0'
        describe = Inspec::Describe.new
        qualifier = [iterator, {}]
        unresources['qualifiers'].each do |parameter|
          Inspec::Log.debug "Terraform::Negative.parse_unmatched_resources #{iterator} qualifier found = #{parameter} MATCHED"
          value = resources.deep_find(parameter.to_s) # value comes from another likely source. Assumption is values are consistent for this type of field
          qualifier[1][parameter] = value
        end
        describe.qualifier.push(qualifier)
        describe.add_test(nil, 'exist', nil, { negated: true }) # last field is negated
        ctrl.add_test(describe)
        unmatched_controls.push(ctrl)
      end
      Inspec::Log.debug "Terraform::Negative.parse_unmatched_resources negative_controls = #{unmatched_controls}"
      unmatched_controls
    end

    # controls for iterators minus the matched resources
    def self.parse_matched_resources(resources, sourcefile, platform)
      Inspec::Log.debug "Terraform::Negative.parse_matched_resources matched_resources #{resources.keys}"
      matched_controls = []
      resources.keys.each do |resource|
        resources[resource].extend Hashie::Extensions::DeepFind # use to find iterators' values from other attributes
        resource_iterators = InspecPlugins::Iggy::InspecHelper.available_resource_iterators(platform)[resource]
        iterator = resource_iterators['iterator']
        ctrl = Inspec::Control.new
        ctrl.id = "NEGATIVE-COVERAGE:#{iterator}"
        ctrl.title = "InSpec-Iggy NEGATIVE-COVERAGE:#{iterator}"
        ctrl.descriptions[:default] = "NEGATIVE-COVERAGE:#{iterator} from the source file #{sourcefile}\nGenerated by InSpec-Iggy v#{InspecPlugins::Iggy::VERSION}"
        ctrl.impact = '1.0'
        describe = Inspec::Describe.new
        qualifier = [iterator, {}]
        resource_iterators['qualifiers'].each do |parameter|
          Inspec::Log.debug "Terraform::Negative.parse_unmatched_resources #{iterator} qualifier found = #{parameter} MATCHED"
          value = resources[resource].deep_find(parameter.to_s) # value comes from resources being evaluated. Assumption is values are consistent for this type of field
          qualifier[1][parameter] = value
        end
        describe.qualifier.push(qualifier)
        # describe.add_test(nil, 'exist', nil, {:negated => true} ) # last field is negated
        describe.add_test(nil, 'exist', nil) # TODO: negative of everything besides the existing nodes
        ctrl.add_test(describe)
        matched_controls.push(ctrl)
      end
      Inspec::Log.debug "Terraform::Negative.parse_matched_resources negative_controls = #{matched_controls}"
      matched_controls
    end
  end
end
